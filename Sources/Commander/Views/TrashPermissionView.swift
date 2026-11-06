import SwiftUI
import AppKit

/// macOS protegge il Cestino: senza Accesso completo al disco il contenuto
/// non è leggibile dalle app di terze parti.
struct TrashPermissionView: View {
    @ObservedObject var tab: BrowserTab
    @EnvironmentObject private var app: AppState

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "trash")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(Palette.textSecondary)

            Text(L("Cannot Read Trash"))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.text)

            Text(L("Trash is protected by macOS. Grant Commander Full Disk Access in System Settings → Privacy & Security → Full Disk Access, then try again."))
                .font(.system(size: 11))
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 330)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 6) {
                Button(L("Open Settings")) {
                    openFullDiskAccessSettings()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)

                HStack(spacing: 8) {
                    Button(L("Open in Finder")) {
                        NSWorkspace.shared.open(trashURL)
                    }
                    .controlSize(.small)

                    Button(L("Try Again")) {
                        tab.reloadCurrent()
                    }
                    .controlSize(.small)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(16)
    }

    private var trashURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".Trash")
    }

    private func openFullDiskAccessSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") else { return }
        NSWorkspace.shared.open(url)
    }
}
