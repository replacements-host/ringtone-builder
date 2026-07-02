import SwiftUI

/// The app's real differentiator: a clear, step-by-step guide for turning the
/// exported .m4r file into an actual ringtone, since there's no public API to
/// do this directly. GarageBand is the primary path (works with no Mac);
/// Finder/Mac is offered as an alternative.
struct InstallInstructionsView: View {
    private enum InstallPath: String, CaseIterable, Identifiable {
        case garageBand = "No Mac (GarageBand)"
        case finder = "With a Mac (Finder)"
        var id: String { rawValue }
    }

    private struct Step {
        let icon: String
        let title: String
        let detail: String
    }

    private static let garageBandSteps: [Step] = [
        Step(
            icon: "waveform",
            title: "Open GarageBand on Your iPhone",
            detail: "GarageBand is a free Apple app — install it from the App Store if you don't have it. Then tap your exported file in Files, choose \"Share\" > \"Open in GarageBand\"."
        ),
        Step(
            icon: "square.and.arrow.up.on.square",
            title: "Share as Ringtone",
            detail: "In GarageBand, tap the song title, then \"Share Song\" (or the Share icon) and choose \"Ringtone\". GarageBand has a direct \"Use as Ringtone\" option since it's a first-party Apple app."
        ),
        Step(
            icon: "checkmark.seal",
            title: "Confirm",
            detail: "GarageBand will save it directly into your ringtones — you can now select it in Settings."
        ),
    ]

    private static let finderSteps: [Step] = [
        Step(
            icon: "cable.connector",
            title: "Connect to a Mac",
            detail: "Connect your iPhone to a Mac with a cable, then open Finder."
        ),
        Step(
            icon: "sidebar.left",
            title: "Select Your Device",
            detail: "In Finder's sidebar, select your iPhone under Locations."
        ),
        Step(
            icon: "arrow.down.doc",
            title: "Drag the File In",
            detail: "Open the \"Tones\" section for your device, then drag the .m4r file (from Files, AirDrop, or wherever you saved it) into that section."
        ),
    ]

    @State private var path: InstallPath = .garageBand
    @State private var currentPage = 0

    private var steps: [Step] {
        path == .garageBand ? Self.garageBandSteps : Self.finderSteps
    }

    var body: some View {
        VStack(spacing: 16) {
            Picker("Path", selection: $path) {
                ForEach(InstallPath.allCases) { p in
                    Text(p.rawValue).tag(p)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)
            .padding(.top, 12)

            TabView(selection: $currentPage) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    InstructionCard(step: index + 1, icon: step.icon, title: step.title, detail: step.detail)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(maxHeight: .infinity)

            // Custom page indicator: takes normal layout space, so it can
            // never overlap card content the way the system page-dot overlay did.
            HStack(spacing: 8) {
                ForEach(steps.indices, id: \.self) { index in
                    Circle()
                        .fill(index == currentPage ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 7, height: 7)
                }
            }

            finalStepCard
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
        }
        .navigationTitle("Install It")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: path) { _, _ in
            currentPage = 0
        }
    }

    private var finalStepCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Final Step", systemImage: "gearshape")
                .font(.subheadline.bold())
            Text("Settings → Sounds & Haptics → Ringtone → select your new tone.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct InstructionCard: View {
    let step: Int
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 48))
                    .foregroundStyle(.tint)
                    .padding(.top, 24)

                Text("Step \(step)")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                Text(title)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                Text(detail)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 32)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 24)
        }
    }
}

#Preview {
    NavigationStack {
        InstallInstructionsView()
    }
}
