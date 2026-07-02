import SwiftUI
import AVFoundation
import MediaPlayer

/// Waveform + drag handles + preview playback + export trigger.
struct TrimEditorView: View {
    let mediaItem: MPMediaItem
    let onExported: (URL) -> Void

    @State private var asset: AVURLAsset?
    @State private var waveform: [Float] = []
    @State private var sourceDuration: TimeInterval = 0
    @State private var selection = TrimSelection(start: 0, end: 30)
    @State private var isLoading = true
    @State private var loadError: String?

    @State private var player: AVAudioPlayer?
    @State private var isPreviewing = false
    @State private var previewCurrentTime: TimeInterval?
    @State private var previewTimer: Timer?

    @State private var isExporting = false
    @State private var exportError: String?

    var body: some View {
        VStack(spacing: 20) {
            if isLoading {
                ProgressView("Loading song…")
            } else if let loadError = loadError {
                ContentUnavailableView("Couldn't Load Song", systemImage: "exclamationmark.triangle", description: Text(loadError))
            } else {
                Text(mediaItem.title ?? "Untitled")
                    .font(.headline)
                Text(mediaItem.artist ?? "")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                WaveformTrimView(
                    waveform: waveform,
                    sourceDuration: sourceDuration,
                    selection: $selection,
                    previewFraction: previewFraction
                )
                .frame(height: 140)
                .padding(.horizontal)

                Text("\(formatted(selection.duration)) selected · max 30s")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Fade in/out", isOn: $selection.fadeEnabled)
                    .padding(.horizontal, 32)

                HStack(spacing: 16) {
                    Button {
                        togglePreview()
                    } label: {
                        Label(isPreviewing ? "Stop" : "Preview", systemImage: isPreviewing ? "stop.fill" : "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        Task { await exportRingtone() }
                    } label: {
                        if isExporting {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Label("Export", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isExporting)
                }
                .padding(.horizontal, 32)

                if let exportError = exportError {
                    Text(exportError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
        }
        .padding(.top)
        .navigationTitle("Trim")
        .navigationBarTitleDisplayMode(.inline)
        .background(SwipeBackDisabler())
        .task {
            await loadAsset()
        }
        .onDisappear {
            stopPreview()
        }
    }

    /// Playhead position as a 0...1 fraction of the current selection, or nil when not previewing.
    private var previewFraction: Double? {
        guard let previewCurrentTime = previewCurrentTime, selection.duration > 0 else { return nil }
        return min(max((previewCurrentTime - selection.start) / selection.duration, 0), 1)
    }

    private func loadAsset() async {
        guard let url = mediaItem.assetURL else {
            loadError = "This song is only available in your Apple Music streaming library — pick a downloaded song instead."
            isLoading = false
            return
        }

        let urlAsset = AVURLAsset(url: url)
        do {
            let duration = try await urlAsset.load(.duration)
            let durationSeconds = CMTimeGetSeconds(duration)
            let initialEnd = min(TrimSelection.maxDuration, durationSeconds)

            let points = try await WaveformGenerator.generate(for: urlAsset)

            asset = urlAsset
            sourceDuration = durationSeconds
            waveform = points
            selection = TrimSelection(start: 0, end: initialEnd)
            isLoading = false
        } catch {
            loadError = "This song couldn't be read. Try a different song."
            isLoading = false
        }
    }

    private func togglePreview() {
        if isPreviewing {
            stopPreview()
        } else {
            startPreview()
        }
    }

    private func startPreview() {
        guard let url = mediaItem.assetURL else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)

            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.currentTime = selection.start
            guard newPlayer.play() else {
                exportError = "Couldn't preview this song."
                return
            }
            player = newPlayer
            isPreviewing = true
            previewCurrentTime = selection.start
            exportError = nil

            previewTimer?.invalidate()
            previewTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { _ in
                guard let player = player else { return }
                if player.currentTime >= selection.end || !player.isPlaying {
                    stopPreview()
                } else {
                    previewCurrentTime = player.currentTime
                }
            }
        } catch {
            exportError = "Couldn't preview this song."
        }
    }

    private func stopPreview() {
        previewTimer?.invalidate()
        previewTimer = nil
        player?.stop()
        player = nil
        isPreviewing = false
        previewCurrentTime = nil
    }

    private func exportRingtone() async {
        guard let asset = asset else { return }
        stopPreview()
        isExporting = true
        exportError = nil
        do {
            let url = try await RingtoneExporter.export(asset: asset, selection: selection)
            isExporting = false
            onExported(url)
        } catch {
            isExporting = false
            exportError = error.localizedDescription
        }
    }

    private func formatted(_ seconds: TimeInterval) -> String {
        String(format: "%.1fs", seconds)
    }
}

/// Renders the waveform, the two draggable trim handles, a drag-to-shift
/// region for moving the whole selection, and a playhead during preview.
private struct WaveformTrimView: View {
    let waveform: [Float]
    let sourceDuration: TimeInterval
    @Binding var selection: TrimSelection
    let previewFraction: Double?

    private let handleWidth: CGFloat = 32

    /// Captured at the start of a whole-selection drag so shifts are computed
    /// as a delta from the gesture's origin rather than compounding per frame.
    @State private var shiftAnchor: (start: TimeInterval, end: TimeInterval)?

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let startX = sourceDuration > 0 ? CGFloat(selection.start / sourceDuration) * width : 0
            let endX = sourceDuration > 0 ? CGFloat(selection.end / sourceDuration) * width : width

            ZStack(alignment: .leading) {
                Canvas { context, size in
                    let midY = size.height / 2
                    let barWidth = size.width / CGFloat(max(waveform.count, 1))
                    for (index, amplitude) in waveform.enumerated() {
                        let x = CGFloat(index) * barWidth
                        let barHeight = max(2, CGFloat(amplitude) * size.height)
                        let inSelection = x >= startX && x <= endX
                        let rect = CGRect(x: x, y: midY - barHeight / 2, width: max(1, barWidth - 1), height: barHeight)
                        context.fill(Path(rect), with: .color(inSelection ? .accentColor : .secondary.opacity(0.4)))
                    }
                }

                // Whole-selection region: tap-and-drag here shifts start and end together.
                Rectangle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: max(0, endX - startX))
                    .offset(x: startX)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let anchor = shiftAnchor ?? (selection.start, selection.end)
                                if shiftAnchor == nil { shiftAnchor = anchor }
                                let deltaSeconds = Double(value.translation.width / width) * sourceDuration
                                let duration = anchor.end - anchor.start
                                var newStart = anchor.start + deltaSeconds
                                newStart = max(0, min(newStart, sourceDuration - duration))
                                selection.start = newStart
                                selection.end = newStart + duration
                            }
                            .onEnded { _ in
                                shiftAnchor = nil
                            }
                    )

                if let previewFraction = previewFraction {
                    let playheadX = startX + CGFloat(previewFraction) * (endX - startX)
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 2)
                        .shadow(radius: 1)
                        .offset(x: playheadX)
                }

                handle(at: startX, geometryWidth: width) { newX in
                    let newStart = sourceDuration * Double(newX / width)
                    let clamped = TrimSelection.clamped(start: newStart, end: selection.end, sourceDuration: sourceDuration)
                    selection.start = clamped.start
                    selection.end = clamped.end
                }

                handle(at: endX, geometryWidth: width) { newX in
                    let newEnd = sourceDuration * Double(newX / width)
                    let clamped = TrimSelection.clamped(start: selection.start, end: newEnd, sourceDuration: sourceDuration)
                    selection.start = clamped.start
                    selection.end = clamped.end
                }
            }
        }
    }

    private func handle(at x: CGFloat, geometryWidth: CGFloat, onDrag: @escaping (CGFloat) -> Void) -> some View {
        Capsule()
            .fill(Color.accentColor)
            .frame(width: 8, height: 90)
            .contentShape(Rectangle().size(width: handleWidth, height: 120))
            .frame(width: handleWidth, height: 120)
            .offset(x: x - handleWidth / 2)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let clampedX = min(max(0, value.location.x + x - handleWidth / 2), geometryWidth)
                        onDrag(clampedX)
                    }
            )
    }
}

/// Disables the interactive edge-swipe-to-go-back gesture while this screen
/// is visible, since the left trim handle sits right where that gesture
/// starts and the two conflict. Restores it on disappear so back-swipe still
/// works everywhere else.
private struct SwipeBackDisabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        SwipeBackDisablingViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    private final class SwipeBackDisablingViewController: UIViewController {
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        }
    }
}
