import SwiftUI
import AppKit
import UniformTypeIdentifiers

final class FolderCustomizationPanelController {
    static let shared = FolderCustomizationPanelController()
    private var panel: NSPanel?

    func show(url: URL) {
        panel?.close()
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 250),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.title = String(format: L("Customize “%@”"), url.lastPathComponent)
        panel.appearance = nil
        panel.isReleasedWhenClosed = false
        panel.contentViewController = NSHostingController(
            rootView: FolderCustomizationView(url: url) { [weak panel] in
                panel?.close()
            }
        )
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
    }
}

private struct FolderCustomizationView: View {
    let url: URL
    let close: () -> Void

    @State private var icon: NSImage
    @State private var message: String?

    init(url: URL, close: @escaping () -> Void) {
        self.url = url
        self.close = close
        _icon = State(initialValue: NSWorkspace.shared.icon(forFile: url.path))
    }

    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: 72, height: 72)

            Text(url.lastPathComponent)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)

            HStack(spacing: 8) {
                Button(L("Choose Icon…")) { chooseIcon() }
                Button(L("Reset Icon")) { resetIcon() }
            }

            if let message {
                Text(message)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack {
                Spacer()
                Button(L("Close"), action: close)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 380, height: 250)
        .background(Palette.window)
    }

    private func chooseIcon() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image]
        panel.prompt = L("Choose")
        panel.message = L("Choose an image to use as the folder icon.")
        guard panel.runModal() == .OK, let imageURL = panel.url,
              let image = NSImage(contentsOf: imageURL) else { return }

        NSWorkspace.shared.setIcon(image, forFile: url.path, options: [])
        icon = image
        message = L("Icon updated. Finder may take a moment to refresh it.")
    }

    private func resetIcon() {
        NSWorkspace.shared.setIcon(nil, forFile: url.path, options: [])
        icon = NSWorkspace.shared.icon(forFile: url.path)
        message = L("Custom icon removed.")
    }
}
