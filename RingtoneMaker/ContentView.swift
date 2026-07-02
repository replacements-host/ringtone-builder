import SwiftUI
import MediaPlayer

/// Root navigation: Picker -> Trim -> Export -> Instructions.
struct ContentView: View {
    @State private var selectedItem: MPMediaItem?
    @State private var exportedFileURL: URL?

    var body: some View {
        NavigationStack {
            SongPickerView { item in
                selectedItem = item
            }
            .navigationDestination(item: $selectedItem) { item in
                TrimEditorView(mediaItem: item) { url in
                    exportedFileURL = url
                }
            }
            .navigationDestination(item: $exportedFileURL) { url in
                ExportResultView(fileURL: url)
            }
        }
    }
}

#Preview {
    ContentView()
}
