import SwiftUI
import AppKit

@main
struct CommanderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var app = AppState()

    var body: some Scene {
        Window("Commander", id: "main") {
            ContentView()
                .environmentObject(app)
                .environmentObject(app.zoom)
                .frame(minWidth: 640, minHeight: 420)
        }
        .windowToolbarStyle(.unified)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1440, height: 880)
        .defaultPosition(.center)
        .commands {
            CommanderCommands(app: app)
        }

        Settings {
            SettingsView()
                .environmentObject(app)
                .environmentObject(app.zoom)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuRefreshWorkItem: DispatchWorkItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)

        // Segue sempre l'aspetto di macOS; l'override è solo per gli snapshot
        // di sviluppo (COMMANDER_APPEARANCE=light|dark).
        if let appearance = ProcessInfo.processInfo.environment["COMMANDER_APPEARANCE"] {
            NSApp.appearance = NSAppearance(named: appearance.lowercased() == "light" ? .aqua : .darkAqua)
        } else {
            NSApp.appearance = nil
        }

        NSApp.activate(ignoringOtherApps: true)

        for name in [
            NSWindow.didResizeNotification,
            NSWindow.didBecomeKeyNotification,
            NSWindow.didResignKeyNotification,
            NSWindow.didEnterFullScreenNotification,
            NSWindow.didExitFullScreenNotification
        ] {
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { note in
                guard let window = note.object as? NSWindow else { return }
                AppDelegate.normalizeWindowButtons(window)
            }
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshMenus),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            forName: NSMenu.didAddItemNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.scheduleMenuRefresh()
        }

        DispatchQueue.main.async {
            for window in NSApp.windows {
                window.minSize = NSSize(width: 640, height: 420)
                window.titlebarAppearsTransparent = false
                window.titleVisibility = .hidden
                window.isMovableByWindowBackground = false
                AppDelegate.normalizeWindowButtons(window)
            }

            if let raw = ProcessInfo.processInfo.environment["COMMANDER_WINDOW_SIZE"] {
                let parts = raw.lowercased().split(separator: "x")
                if parts.count == 2,
                   let width = Double(parts[0]),
                   let height = Double(parts[1]),
                   let window = NSApp.windows.first(where: { !($0 is NSPanel) }) {
                    window.setContentSize(NSSize(width: width, height: height))
                    window.center()
                }
            }

            self.refreshMenus()
        }

        // Hook di diagnostica: cattura la UI senza permessi di registrazione schermo.
        if let path = ProcessInfo.processInfo.environment["COMMANDER_SNAPSHOT"] {
            let delay = Double(ProcessInfo.processInfo.environment["COMMANDER_SNAPSHOT_DELAY"] ?? "") ?? 2.0
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                AppDelegate.captureSnapshot(to: path)
                if ProcessInfo.processInfo.environment["COMMANDER_SNAPSHOT_EXIT"] == "1" {
                    NSApp.terminate(nil)
                }
            }
        }

        if ProcessInfo.processInfo.environment["COMMANDER_PRINT_BUTTONS"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                guard let window = NSApp.windows.first(where: { !($0 is NSPanel) }) else { return }
                let names: [(NSWindow.ButtonType, String)] = [
                    (.closeButton, "close"), (.miniaturizeButton, "mini"), (.zoomButton, "zoom")
                ]
                for (type, name) in names {
                    if let button = window.standardWindowButton(type) {
                        let line = "BTN \(name) frame=\(button.frame) super=\(String(describing: button.superview?.frame))\n"
                        FileHandle.standardError.write(Data(line.utf8))
                    }
                }
                let line = "WINDOW frame=\(window.frame) content=\(window.contentView?.frame ?? .zero) layout=\(window.contentLayoutRect)\n"
                FileHandle.standardError.write(Data(line.utf8))
            }
        }

        if ProcessInfo.processInfo.environment["COMMANDER_PRINT_MENU"] == "1" {
            let dump = {
                for item in NSApp.mainMenu?.items ?? [] {
                    let sub = item.submenu?.items.map(\.title) ?? []
                    print("MENU:", item.title, "→", sub)
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: dump)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.6, execute: dump)
        }

        if ProcessInfo.processInfo.environment["COMMANDER_HITTEST_DEBUG"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                guard let window = NSApp.windows
                    .filter({ $0.isVisible && !($0 is NSPanel) })
                    .max(by: {
                        ($0.frame.width * $0.frame.height) < ($1.frame.width * $1.frame.height)
                    }) else { return }

                let targets = ClickRegistry.shared.targets(in: window)
                print("TARGETS:", targets.count)

                if let target = targets.first {
                    let rect = target.superview.map {
                        $0.convert(target.frame, to: nil)
                    } ?? target.frame
                    let hit = ClickRegistry.shared.target(
                        at: NSPoint(x: rect.midX, y: rect.midY),
                        in: window
                    )
                    print(
                        "TARGET rect:", rect,
                        "frame:", target.frame,
                        "hitSelf:", hit === target
                    )
                }
            }
        }
    }

    /// Allinea i semafori alla geometria standard delle finestre macOS con
    /// toolbar unificata: 14×14 pt e passo di 23 pt.
    static func normalizeWindowButtons(_ window: NSWindow) {
        if ProcessInfo.processInfo.environment["COMMANDER_NO_TRAFFIC_NORMALIZE"] == "1" { return }
        guard !(window is NSPanel),
              let close = window.standardWindowButton(.closeButton),
              let mini = window.standardWindowButton(.miniaturizeButton),
              let zoom = window.standardWindowButton(.zoomButton),
              let host = close.superview else { return }

        let hasToolbar = host.bounds.height > 44
        let originX: CGFloat = hasToolbar ? 19 : 9
        let size = hasToolbar ? NSSize(width: 20, height: 20) : NSSize(width: 18, height: 18)
        let originY = (host.bounds.height - size.height) / 2
        let step: CGFloat = hasToolbar ? 23 : 21

        for (index, button) in [close, mini, zoom].enumerated() {
            let target = NSRect(
                x: originX + CGFloat(index) * step,
                y: originY,
                width: size.width,
                height: size.height
            )
            if button.frame != target {
                button.frame = target
            }

            // Il contenuto nativo è 14×14: lo portiamo a 20×20 per
            // avvicinarci ai nuovi controlli di macOS 27.
            for content in button.subviews {
                content.frame = NSRect(origin: .zero, size: size)
                if content.layer == nil { content.wantsLayer = true }
            }
            button.needsDisplay = true
        }
    }

    // MARK: - Menu

    @objc private func refreshMenus() {
        guard let mainMenu = NSApp.mainMenu else { return }

        // SwiftUI crea un menu "View" vuoto; i comandi personalizzati sono già
        // nel nostro menu "View" localizzato.
        for item in mainMenu.items where item.title == "View" && (item.submenu?.items.isEmpty ?? true) {
            mainMenu.removeItem(item)
        }

        guard L10n.isItalian else { return }

        for item in mainMenu.items {
            item.title = L(item.title)
            if let submenu = item.submenu {
                AppDelegate.translate(submenu)
            }
        }
    }

    private static func translate(_ menu: NSMenu) {
        for item in menu.items {
            if item.isSeparatorItem { continue }
            item.title = L(item.title)
            if let submenu = item.submenu {
                translate(submenu)
            }
        }
    }

    private func scheduleMenuRefresh() {
        menuRefreshWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.refreshMenus()
        }
        menuRefreshWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: item)
    }

    // MARK: - Snapshot diagnostico

    private static func captureSnapshot(to path: String) {
        if ProcessInfo.processInfo.environment["COMMANDER_SNAPSHOT_PANEL"] == "1" {
            let copyTitle = L("Copying…")
            let moveTitle = L("Moving…")
            if let panel = NSApp.windows.first(where: {
                $0.isVisible && ($0.title == copyTitle || $0.title == moveTitle)
            }) {
                capture(window: panel, to: path)
                return
            }
        }

        if ProcessInfo.processInfo.environment["COMMANDER_SNAPSHOT_INFO"] == "1",
           let panel = NSApp.windows.first(where: {
               $0.isVisible && $0.identifier?.rawValue == "FileInfoPanel"
           }) {
            capture(window: panel, to: path)
            return
        }

        if ProcessInfo.processInfo.environment["COMMANDER_SNAPSHOT_SHEET"] == "1" {
            if let sheet = NSApp.windows.first(where: {
                $0.isVisible && ($0.isSheet || $0.sheetParent != nil)
            }) {
                capture(window: sheet, to: path)
                return
            }
        }

        if ProcessInfo.processInfo.environment["COMMANDER_SNAPSHOT_SETTINGS"] == "1",
           let settings = NSApp.windows.first(where: {
               $0.isVisible && ($0.title == "Settings" || $0.title == "Impostazioni" || $0.identifier?.rawValue.contains("Settings") == true)
           }) {
            capture(window: settings, to: path)
            return
        }

        let candidates = NSApp.windows.filter { $0.isVisible && $0.contentView != nil }
        guard let window = candidates.max(by: {
            ($0.frame.width * $0.frame.height) < ($1.frame.width * $1.frame.height)
        }) else { return }
        capture(window: window, to: path)
    }

    private static func capture(window: NSWindow, to path: String) {
        guard let content = window.contentView else { return }
        let view = content.superview ?? content
        let bounds = view.bounds
        guard bounds.width > 0, bounds.height > 0 else { return }

        if let rep = view.bitmapImageRepForCachingDisplay(in: bounds) {
            view.cacheDisplay(in: bounds, to: rep)
            if let data = rep.representation(using: .png, properties: [:]) {
                try? data.write(to: URL(fileURLWithPath: path))
                return
            }
        }

        guard let layer = view.layer else { return }
        let scale = window.backingScaleFactor
        let width = Int(bounds.width * scale)
        let height = Int(bounds.height * scale)
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return }
        context.scaleBy(x: scale, y: scale)
        layer.render(in: context)
        guard let image = context.makeImage() else { return }
        let rep = NSBitmapImageRep(cgImage: image)
        if let data = rep.representation(using: .png, properties: [:]) {
            try? data.write(to: URL(fileURLWithPath: path))
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }
}
