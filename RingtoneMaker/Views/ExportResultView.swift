import SwiftUI

/// Success screen: confirms the export and offers a share sheet, then routes
/// to the install instructions.
struct ExportResultView: View {
    let fileURL: URL

    @State private var isSharePresented = false
    @State private var showInstructions = false
    @State private var activityController: UIActivityViewController?

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
            .disabled(activityController == nil || isSharePresented)

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
        .onAppear {
            // UIActivityViewController's first presentation has a noticeable
            // one-time cost (enumerating share extensions/apps that can
            // handle the file). Building it now, while the user is still
            // reading this screen, hides most of that behind the tap.
            if activityController == nil {
                activityController = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
            }
        }
        .sheet(isPresented: $isSharePresented) {
            if let activityController = activityController {
                ActivitySheet(controller: activityController)
            }
        }
        .navigationDestination(isPresented: $showInstructions) {
            InstallInstructionsView()
        }
    }
}

/// Presents a pre-built `UIActivityViewController` instance rather than
/// constructing one at presentation time.
private struct ActivitySheet: UIViewControllerRepresentable {
    let controller: UIActivityViewController

    func makeUIViewController(context: Context) -> UIActivityViewController {
        controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
