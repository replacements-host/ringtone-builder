import SwiftUI

/// Success screen: confirms the export and offers a share sheet, then routes
/// to the install instructions.
struct ExportResultView: View {
    let fileURL: URL

    @State private var isSharePresented = false
    @State private var showInstructions = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            Text("Ringtone Ready")
                .font(.title.bold())

            Text("Your ringtone is saved as a file. Share it now, or follow the steps to actually install it as your ringtone.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                isSharePresented = true
            } label: {
                Label("Share or Save File", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .padding(.horizontal, 32)

            Button {
                showInstructions = true
            } label: {
                Label("How to Install It", systemImage: "arrow.right.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
        .navigationTitle("Export")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isSharePresented) {
            ShareSheet(items: [fileURL])
        }
        .navigationDestination(isPresented: $showInstructions) {
            InstallInstructionsView()
        }
    }
}

/// Thin wrapper around `UIActivityViewController`.
private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
