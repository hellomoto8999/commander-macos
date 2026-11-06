import SwiftUI
import AppKit

/// Finestra “Get Info” in stile Finder. Non usa il Finder via AppleScript:
/// mostra gli stessi metadati principali in una finestra nativa.
final class FileInfoPanelController {
    static let shared = FileInfoPanelController()

    private var panel: NSPanel?


    /// Apre la vera finestra Informazioni del Finder per un singolo elemento.
    /// Richiede il permesso Automazione; in caso di rifiuto si usa il pannello nativo.
    static func openFinderInfo(for url: URL) -> Bool {
        let escaped = url.path
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let source = """
        tell application "Finder"
            activate
            open information window of (POSIX file "\(escaped)" as alias)
        end tell
        """
        guard let script = NSAppleScript(source: source) else { return false }
        var error: NSDictionary?
        _ = script.executeAndReturnError(&error)
        return error == nil
    }

    func show(urls: [URL]) {
        let valid = FileSystem.existingItems(at: urls)
        guard !valid.isEmpty else { return }

        panel?.close()

        let title: String
        if valid.count == 1 {
            title = String(format: L("%@ Info"), valid[0].lastPathComponent)
        } else {
            title = String(format: L("%d Items Info"), valid.count)
        }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 430),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.title = title
        panel.identifier = NSUserInterfaceItemIdentifier("FileInfoPanel")
        panel.appearance = nil
        panel.isFloatingPanel = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.fullScreenAuxiliary]
        panel.contentViewController = NSHostingController(
            rootView: FileInfoView(urls: valid) { [weak panel] in
                panel?.close()
            }
        )
        panel.setContentSize(NSSize(width: 400, height: 430))
        panel.minSize = NSSize(width: 360, height: 360)
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
    }
}

private struct FileInfoView: View {
    let urls: [URL]
    let onClose: () -> Void

    @State private var calculatedSize: Int64?

    private var multiple: Bool { urls.count > 1 }
    private var first: FileItem? { urls.first.map(FileItem.init) }

    private var displayName: String {
        if multiple { return L10n.items(urls.count) }
        return first?.name ?? urls.first?.lastPathComponent ?? ""
    }

    private var displayKind: String {
        if multiple { return L("Multiple items") }
        return first?.displayKind ?? ""
    }

    private var whereText: String {
        guard let first else { return "—" }
        if multiple {
            let parents = Set(urls.map { $0.deletingLastPathComponent().standardizedFileURL })
            return parents.count == 1 ? first.url.deletingLastPathComponent().path : L("Multiple locations")
        }
        return first.url.deletingLastPathComponent().path
    }

    private var sizeText: String {
        if let calculatedSize { return Format.bytes(calculatedSize) }
        if multiple {
            return Format.bytes(urls.reduce(Int64(0)) { partial, url in
                partial + Int64((try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
            })
        }
        guard let first else { return "—" }
        return first.isDirectory ? "—" : Format.bytes(first.size)
    }

    private var tags: [String] {
        guard let first, !multiple else { return [] }
        return first.tagNames
    }

    private var dates: (created: String, modified: String) {
        guard let first else { return ("—", "—") }
        if multiple { return ("—", "—") }
        return (Format.fullDate(first.created), Format.fullDate(first.modified))
    }

    private var permissionsText: String? {
        guard !multiple, let url = urls.first else { return nil }
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        guard let permissions = attributes?[.posixPermissions] as? NSNumber else { return nil }
        return String(format: "%03o", permissions.intValue)
    }

    private var ownerText: String? {
        guard !multiple, let url = urls.first else { return nil }
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return attributes?[.ownerAccountName] as? String
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: urls.first?.path ?? ""))
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 64, height: 64)

                VStack(alignment: .leading, spacing: 4) {
                    Text(displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.text)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .textSelection(.enabled)

                    Text(displayKind)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Palette.textSecondary)
                }
                Spacer(minLength: 0)
            }

            Divider()

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 7) {
                infoRow(L("Size"), sizeText)
                infoRow(L("Where"), whereText)
                if !multiple {
                    infoRow(L("Created"), dates.created)
                    infoRow(L("Modified"), dates.modified)
                }
                if let ownerText {
                    infoRow(L("Owner"), ownerText)
                }
                if let permissionsText {
                    infoRow(L("Permissions"), permissionsText)
                }
                if !tags.isEmpty {
                    infoRow(L("Tags"), tags.joined(separator: ", "))
                }
            }
            .font(.system(size: 11.5))

            Spacer(minLength: 0)

            HStack {
                Button(L("Show in Finder")) {
                    NSWorkspace.shared.activateFileViewerSelecting(urls)
                }
                .controlSize(.small)

                Spacer()

                Button(L("Close"), action: onClose)
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.small)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.window)
        .task(id: urls) {
            guard let first, first.isDirectory, !multiple else { return }
            let size = await Task.detached(priority: .utility) {
                FileSystem.size(of: first.url)
            }.value
            calculatedSize = size
        }
    }

    @ViewBuilder
    private func infoRow(_ label: String, _ value: String) -> some View {
        GridRow(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(Palette.textSecondary)
                .frame(width: 78, alignment: .leading)
            Text(value)
                .foregroundStyle(Palette.text)
                .textSelection(.enabled)
                .lineLimit(3)
                .truncationMode(.middle)
        }
    }
}
