import SwiftUI

/// The app's real differentiator: a clear, step-by-step guide for turning the
/// exported .m4r file into an actual ringtone, since there's no public API to
/// do this directly. GarageBand is the primary path (works with no Mac);
/// Finder/Mac is offered as an alternative.
struct InstallInstructionsView: View {
    private enum Path: String, CaseIterable, Identifiable {
        case garageBand = "No Mac (GarageBand)"
        case finder = "With a Mac (Finder)"
        var id: String { rawValue }
    }

    @State private var path: Path = .garageBand

    var body: some View {
        VStack(spacing: 20) {
            Text("Your ringtone is saved as a file. Now let's get it onto your phone as an actual ringtone.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.top, 12)

            Picker("Path", selection: $path) {
                ForEach(Path.allCases) { p in
                    Text(p.rawValue).tag(p)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)

            TabView {
                switch path {
                case .garageBand:
                    garageBandCards
                case .finder:
                    finderCards
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .frame(maxHeight: .infinity)

            finalStepCard
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
        }
        .navigationTitle("Install It")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var garageBandCards: some View {
        InstructionCard(
            step: 1,
            icon: "waveform",
            title: "Open GarageBand on Your iPhone",
            detail: "GarageBand is a free Apple app — install it from the App Store if you don't have it. Then tap your exported file in Files, choose \"Share\" > \"Open in GarageBand\"."
        )
        InstructionCard(
            step: 2,
            icon: "square.and.arrow.up.on.square",
            title: "Share as Ringtone",
            detail: "In GarageBand, tap the song title, then \"Share Song\" (or the Share icon) and choose \"Ringtone\". GarageBand has a direct \"Use as Ringtone\" option since it's a first-party Apple app."
        )
        InstructionCard(
            step: 3,
            icon: "checkmark.seal",
            title: "Confirm",
            detail: "GarageBand will save it directly into your ringtones — you can now select it in Settings."
        )
    }

    @ViewBuilder
    private var finderCards: some View {
        InstructionCard(
            step: 1,
            icon: "cable.connector",
            title: "Connect to a Mac",
            detail: "Connect your iPhone to a Mac with a cable, then open Finder."
        )
        InstructionCard(
            step: 2,
            icon: "sidebar.left",
            title: "Select Your Device",
            detail: "In Finder's sidebar, select your iPhone under Locations."
        )
        InstructionCard(
            step: 3,
            icon: "arrow.down.doc",
            title: "Drag the File In",
            detail: "Open the \"Tones\" section for your device, then drag the .m4r file (from Files, AirDrop, or wherever you saved it) into that section."
        )
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
