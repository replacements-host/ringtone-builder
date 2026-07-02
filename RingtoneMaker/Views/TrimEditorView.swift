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
    @State private var previewStopTimer: Timer?

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
                    selection: $selection
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
        .task {
            await loadAsset()
        }
        .onDisappear {
            stopPreview()
        }
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
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.currentTime = selection.start
            newPlayer.play()
            player = newPlayer
            isPreviewing = true

            let remaining = selection.duration
            previewStopTimer?.invalidate()
            previewStopTimer = Timer.scheduledTimer(withTimeInterval: remaining, repeats: false) { _ in
                stopPreview()
            }
        } catch {
            exportError = "Couldn't preview this song."
        }
    }

    private func stopPreview() {
        previewStopTimer?.invalidate()
        previewStopTimer = nil
        player?.stop()
        player = nil
        isPreviewing = false
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

/// Renders the waveform and two draggable trim handles.
private struct WaveformTrimView: View {
    let waveform: [Float]
    let sourceDuration: TimeInterval
    @Binding var selection: TrimSelection

    private let handleWidth: CGFloat = 24

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

                Rectangle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: max(0, endX - startX))
                    .offset(x: startX)

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
            .frame(width: 6, height: 90)
            .contentShape(Rectangle().size(width: handleWidth, height: 120))
            .frame(width: handleWidth, height: 120)
            .offset(x: x - handleWidth / 2)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let clampedX = min(max(0, value.location.x), geometryWidth)
                        onDrag(clampedX)
                    }
            )
    }
}
