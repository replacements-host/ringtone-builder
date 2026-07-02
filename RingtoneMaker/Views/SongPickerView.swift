import SwiftUI
import MediaPlayer

/// Entry screen: launches the system media picker and filters the result down
/// to tracks that AVFoundation can actually export (see Engine/RingtoneExporter).
struct SongPickerView: View {
    let onPick: (MPMediaItem) -> Void

    @State private var isPickerPresented = false
    @State private var unusableTrackTitle: String?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "music.note.list")
                .font(.system(size: 64))
                .foregroundStyle(.tint)

            Text("Ringtone Maker")
                .font(.largeTitle.bold())

            Text("Pick a song from your library to trim into a ringtone.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Text("Works best with songs downloaded to your device.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button {
                isPickerPresented = true
            } label: {
                Label("Choose a Song", systemImage: "music.note")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 32)
            .padding(.top, 8)

            Spacer()
            Spacer()

            Text("For use with music you own or have the rights to use as a personal ringtone.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 12)
        }
        .sheet(isPresented: $isPickerPresented) {
            MediaPickerRepresentable { item in
                guard let item = item else { return }
                if MediaExportability.isExportable(item) {
                    onPick(item)
                } else {
                    unusableTrackTitle = item.title ?? "That song"
                }
            }
        }
        .alert(
            "Can't Use This Song",
            isPresented: Binding(
                get: { unusableTrackTitle != nil },
                set: { if !$0 { unusableTrackTitle = nil } }
            )
        ) {
            Button("OK", role: .cancel) { unusableTrackTitle = nil }
        } message: {
            Text("\(unusableTrackTitle ?? "This song") is only available in your Apple Music streaming library — pick a downloaded song instead.")
        }
    }
}

/// Whether AVFoundation can read and export this item locally.
enum MediaExportability {
    static func isExportable(_ item: MPMediaItem) -> Bool {
        guard let assetURL = item.assetURL else { return false }
        if item.isCloudItem { return false }
        _ = assetURL
        return true
    }
}

/// UIKit bridge for `MPMediaPickerController`.
private struct MediaPickerRepresentable: UIViewControllerRepresentable {
    let onSelect: (MPMediaItem?) -> Void

    func makeUIViewController(context: Context) -> MPMediaPickerController {
        let picker = MPMediaPickerController(mediaTypes: .music)
        picker.allowsPickingMultipleItems = false
        picker.showsCloudItems = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: MPMediaPickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }

    final class Coordinator: NSObject, MPMediaPickerControllerDelegate {
        let onSelect: (MPMediaItem?) -> Void

        init(onSelect: @escaping (MPMediaItem?) -> Void) {
            self.onSelect = onSelect
        }

        func mediaPicker(_ mediaPicker: MPMediaPickerController, didPickMediaItems mediaItemCollection: MPMediaItemCollection) {
            mediaPicker.dismiss(animated: true) {
                self.onSelect(mediaItemCollection.items.first)
            }
        }

        func mediaPickerDidCancel(_ mediaPicker: MPMediaPickerController) {
            mediaPicker.dismiss(animated: true) {
                self.onSelect(nil)
            }
        }
    }
}
