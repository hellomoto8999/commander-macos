import AppKit
import UniformTypeIdentifiers

/// Costruisce i menu contestuali AppKit per file e cartelle, con le voci
/// che Finder mostra con il tasto destro e con Opzione + tasto destro.
enum FileMenuBuilder {

    private final class MenuAction: NSObject {
        let closure: () -> Void

        init(_ closure: @escaping () -> Void) {
            self.closure = closure
        }

        @objc func run(_ sender: Any?) {
            closure()
        }
    }

    static func menu(
        for item: FileItem,
        tab: BrowserTab,
        app: AppState,
        option: Bool = false
    ) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let targets: [URL] = tab.selection.contains(item.url)
            ? FileSystem.existingItems(at: Array(tab.selection))
            : [item.url]
        let effectiveTargets = targets.isEmpty ? [item.url] : targets
        let multiple = effectiveTargets.count > 1
        let single = !multiple
        let allFolders = effectiveTargets.allSatisfy { FileItem(url: $0).isBrowsableFolder }

        add(menu, L("Open"), key: "o", icon: "arrow.up.forward.app") {
            DispatchQueue.main.async {
                if single {
                    tab.open(item)
                } else {
                    for target in effectiveTargets {
                        let candidate = FileItem(url: target)
                        if candidate.isBrowsableFolder {
                            app.newTab(at: target)
                        } else {
                            NSWorkspace.shared.open(target)
                        }
                    }
                }
            }
        }

        if single, item.isBrowsableFolder {
            add(menu, L("Open in New Tab"), icon: "plus.rectangle.on.rectangle") {
                DispatchQueue.main.async { app.newTab(at: item.url) }
            }
        }

        if single, item.isBrowsableFolder {
            let paste = add(menu, L("Paste Item"), icon: "doc.on.clipboard") {
                app.paste(into: item.url)
            }
            paste.isEnabled = FileClipboard.hasFiles()
        }

        if !allFolders, single {
            addOpenWithSubmenu(to: menu, item: item, targets: effectiveTargets, app: app, always: false)
        }

        add(menu, L("Get Info"), key: "i", icon: "info.circle") {
            DispatchQueue.main.async { app.getInfo() }
        }

        let rename = add(menu, L("Rename"), icon: "pencil") {
            DispatchQueue.main.async { app.beginRename(item.url) }
        }
        rename.isEnabled = single

        add(menu, multiple
            ? String(format: L("Compress %d Items"), effectiveTargets.count)
            : String(format: L("Compress “%@”"), item.name), icon: "archivebox") {
            app.compress(effectiveTargets)
        }

        add(menu, L("Duplicate"), key: "d", icon: "plus.square.on.square") {
            app.duplicate(effectiveTargets)
        }

        add(menu, L("Make Alias"), icon: "arrow.triangle.turn.up.right.diamond") {
            app.makeAlias(effectiveTargets)
        }

        add(menu, L("Quick Look"), key: "y", icon: "eye") {
            DispatchQueue.main.async {
                QuickLookController.shared.toggle(urls: effectiveTargets)
            }
        }

        menu.addItem(.separator())

        add(menu, L("Cut"), key: "x", icon: "scissors") {
            FileClipboard.write(effectiveTargets, cut: true)
        }

        add(menu, L("Copy"), key: "c", icon: "doc.on.doc") {
            FileClipboard.write(effectiveTargets, cut: false)
        }

        add(menu, L("Move to Trash"), key: "\u{8}", icon: "trash") {
            app.trash(effectiveTargets)
        }

        addShareSubmenu(to: menu, targets: effectiveTargets, tab: tab, app: app)
        addTagStrip(to: menu, targets: effectiveTargets, app: app)

        if single, item.isBrowsableFolder {
            add(menu, L("Customize Folder…"), icon: "paintpalette") {
                app.customizeFolder(item.url)
            }
        }

        addQuickActions(to: menu, targets: effectiveTargets)
        addServicesSubmenu(to: menu)

        menu.addItem(.separator())

        add(menu, L("Show in Finder"), icon: "folder") {
            NSWorkspace.shared.activateFileViewerSelecting(effectiveTargets)
        }

        if single, item.isBrowsableFolder {
            add(menu, L("Open in Other Pane"), icon: "rectangle.split.2x1") {
                DispatchQueue.main.async { app.openInOtherPane(item.url) }
            }
            add(menu, L("Add to Favorites"), icon: "star") {
                app.addFavorite(item.url)
            }
            add(menu, L("Folder Actions Setup…"), icon: "gearshape.2") {
                NSWorkspace.shared.open(
                    URL(fileURLWithPath: "/System/Library/CoreServices/Applications/Folder Actions Setup.app")
                )
            }
            add(menu, L("New Terminal at Folder"), icon: "terminal") {
                app.openTerminal(at: item.url)
            }
            add(menu, L("New Terminal Tab at Folder"), icon: "terminal") {
                app.openTerminalTab(at: item.url)
            }
        }

        if option {
            menu.addItem(.separator())

            add(menu, multiple
                ? String(format: L("Copy %d Items as Pathnames"), effectiveTargets.count)
                : String(format: L("Copy “%@” as Pathname"), item.name)) {
                let paths = effectiveTargets.map(\.path).joined(separator: "\n")
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(paths, forType: .string)
            }

            if single, item.isPackage {
                add(menu, L("Show Package Contents")) {
                    DispatchQueue.main.async { app.newTab(at: item.url) }
                }
            }

            if !allFolders, single {
                addOpenWithSubmenu(to: menu, item: item, targets: effectiveTargets, app: app, always: true)
            }
        }

        return menu
    }

    // MARK: - Helper menu

    @discardableResult
    private static func add(
        _ menu: NSMenu,
        _ title: String,
        key: String = "",
        icon: String? = nil,
        enabled: Bool = true,
        action: @escaping () -> Void
    ) -> NSMenuItem {
        let target = MenuAction(action)
        let item = NSMenuItem(title: title, action: #selector(MenuAction.run(_:)), keyEquivalent: key)
        item.target = target
        item.representedObject = target
        item.isEnabled = enabled
        if let icon, let image = NSImage(systemSymbolName: icon, accessibilityDescription: nil) {
            item.image = image
        }
        if !key.isEmpty {
            item.keyEquivalentModifierMask = .command
        }
        menu.addItem(item)
        return item
    }

    // MARK: - Apri con

    private static func addOpenWithSubmenu(
        to menu: NSMenu,
        item: FileItem,
        targets: [URL],
        app: AppState,
        always: Bool
    ) {
        var seen = Set<String>()
        let applications = NSWorkspace.shared
            .urlsForApplications(toOpen: item.url)
            .filter {
                let key = Bundle(url: $0)?.bundleIdentifier ?? $0.standardizedFileURL.path
                return seen.insert(key).inserted
            }
            .sorted {
                FileManager.default.displayName(atPath: $0.path)
                    .localizedStandardCompare(FileManager.default.displayName(atPath: $1.path)) == .orderedAscending
            }
        let defaultApplication = NSWorkspace.shared.urlForApplication(toOpen: item.url)
        let submenu = NSMenu()
        submenu.autoenablesItems = false

        for application in applications.prefix(12) {
            let title = FileManager.default.displayName(atPath: application.path)
            let menuItem = NSMenuItem(
                title: title,
                action: #selector(MenuAction.run(_:)),
                keyEquivalent: ""
            )
            let target = MenuAction {
                if always {
                    setDefaultApplication(application, for: targets, app: app)
                } else {
                    open(targets, with: application, app: app)
                }
            }
            menuItem.target = target
            menuItem.representedObject = target
            menuItem.image = NSWorkspace.shared.icon(forFile: application.path)
            if always, application == defaultApplication {
                menuItem.state = .on
            }
            submenu.addItem(menuItem)
        }

        if !submenu.items.isEmpty {
            submenu.addItem(.separator())
        }

        let other = NSMenuItem(
            title: L("Other…"),
            action: #selector(MenuAction.run(_:)),
            keyEquivalent: ""
        )
        let otherTarget = MenuAction {
            let panel = NSOpenPanel()
            panel.title = always ? L("Always Open With") : L("Open With")
            panel.message = L("Choose an application.")
            panel.prompt = always ? L("Choose") : L("Open")
            panel.allowedContentTypes = [.application]
            panel.canChooseFiles = true
            panel.canChooseDirectories = false
            panel.allowsMultipleSelection = false
            panel.directoryURL = URL(fileURLWithPath: "/Applications")
            panel.begin { response in
                guard response == .OK, let application = panel.url else { return }
                if always {
                    setDefaultApplication(application, for: targets, app: app)
                } else {
                    open(targets, with: application, app: app)
                }
            }
        }
        other.target = otherTarget
        other.representedObject = otherTarget
        submenu.addItem(other)

        let submenuItem = NSMenuItem(
            title: always ? L("Always Open With") : L("Open With"),
            action: nil,
            keyEquivalent: ""
        )
        submenuItem.submenu = submenu
        menu.addItem(submenuItem)
    }

    private static func open(_ urls: [URL], with application: URL, app: AppState) {
        NSWorkspace.shared.open(
            urls,
            withApplicationAt: application,
            configuration: NSWorkspace.OpenConfiguration()
        ) { _, error in
            guard let error else { return }
            DispatchQueue.main.async {
                app.errorMessage = ErrorInfo(
                    title: L("Operation Failed"),
                    message: String(
                        format: L("Could not open “%@” with “%@”."),
                        urls.first?.lastPathComponent ?? "",
                        FileManager.default.displayName(atPath: application.path)
                    ) + "\n" + error.localizedDescription
                )
            }
        }
    }

    private static func setDefaultApplication(_ application: URL, for urls: [URL], app: AppState) {
        guard let target = urls.first else { return }
        NSWorkspace.shared.setDefaultApplication(
            at: application,
            toOpenFileAt: target
        ) { error in
            guard let error else { return }
            DispatchQueue.main.async {
                app.errorMessage = ErrorInfo(
                    title: L("Operation Failed"),
                    message: String(
                        format: L("Could not set “%@” as the default application."),
                        FileManager.default.displayName(atPath: application.path)
                    ) + "\n" + error.localizedDescription
                )
            }
        }
    }

    // MARK: - Condividi

    private static func addShareSubmenu(
        to menu: NSMenu,
        targets: [URL],
        tab: BrowserTab,
        app: AppState
    ) {
        let submenu = NSMenu()
        submenu.autoenablesItems = false

        for service in NSSharingService.sharingServices(forItems: targets) {
            let target = MenuAction {
                service.perform(withItems: targets)
            }
            let menuItem = NSMenuItem(
                title: service.title,
                action: #selector(MenuAction.run(_:)),
                keyEquivalent: ""
            )
            menuItem.target = target
            menuItem.representedObject = target
            menuItem.image = service.image
            submenu.addItem(menuItem)
        }

        if !submenu.items.isEmpty {
            submenu.addItem(.separator())
        }

        let moreTarget = MenuAction {
            DispatchQueue.main.async {
                tab.selection = Set(targets)
                app.shareSelection()
            }
        }
        let more = NSMenuItem(
            title: L("Share…"),
            action: #selector(MenuAction.run(_:)),
            keyEquivalent: ""
        )
        more.target = moreTarget
        more.representedObject = moreTarget
        submenu.addItem(more)

        let item = NSMenuItem(title: L("Share…"), action: nil, keyEquivalent: "")
        item.image = NSImage(systemSymbolName: "square.and.arrow.up", accessibilityDescription: nil)
        item.submenu = submenu
        menu.addItem(item)
    }


    // MARK: - Tag color strip

    private static func addTagStrip(to menu: NSMenu, targets: [URL], app: AppState) {
        guard !app.tagDefinitions.isEmpty else { return }
        let strip = TagStripView(tags: app.tagDefinitions, targets: targets, app: app)
        let item = NSMenuItem()
        item.view = strip
        item.setAccessibilityLabel(L("Tags"))
        menu.addItem(item)
    }

    private final class TagStripView: NSView {
        private var actions: [MenuAction] = []

        init(tags: [FinderTagDefinition], targets: [URL], app: AppState) {
            let visible = Array(tags.prefix(7))
            let width = max(180, CGFloat(visible.count) * 24 + 16)
            super.init(frame: NSRect(x: 0, y: 0, width: width, height: 30))

            for (index, tag) in visible.enumerated() {
                let action = MenuAction {
                    app.toggleTag(tag.name, on: targets)
                }
                actions.append(action)
                let button = NSButton(frame: NSRect(x: 10 + CGFloat(index) * 24, y: 5, width: 20, height: 20))
                button.isBordered = false
                button.bezelStyle = .regularSquare
                button.image = FileMenuBuilder.tagImage(color: tag.nsColor)
                button.imagePosition = .imageOnly
                button.imageScaling = .scaleProportionallyDown
                button.target = action
                button.action = #selector(MenuAction.run(_:))
                button.toolTip = tag.name
                button.focusRingType = .none
                addSubview(button)
            }
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }

    // MARK: - Quick Actions

    private static func addQuickActions(to menu: NSMenu, targets: [URL]) {
        let services = QuickActionRunner.discover()
        let userServicesPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Services").path
        let quick = services.filter(\.requiresFinder)
        let direct = services.filter {
            !$0.requiresFinder && $0.workflowURL.path.hasPrefix(userServicesPath)
        }

        if !quick.isEmpty {
            let submenu = NSMenu()
            submenu.autoenablesItems = false
            for action in quick {
                let target = MenuAction {
                    _ = QuickActionRunner.perform(action, on: targets)
                }
                let item = NSMenuItem(
                    title: action.name,
                    action: #selector(MenuAction.run(_:)),
                    keyEquivalent: ""
                )
                item.target = target
                item.representedObject = target
                submenu.addItem(item)
            }
            let quickItem = NSMenuItem(title: L("Quick Actions"), action: nil, keyEquivalent: "")
            quickItem.image = NSImage(systemSymbolName: "bolt.circle", accessibilityDescription: nil)
            quickItem.submenu = submenu
            menu.addItem(quickItem)
        }

        for action in direct {
            add(menu, action.name, icon: "lock.open") {
                _ = QuickActionRunner.perform(action, on: targets)
            }
        }
    }

    // MARK: - Tag

    private static func addTagsSubmenu(
        to menu: NSMenu,
        targets: [URL],
        app: AppState,
        hasTags: Bool
    ) {
        let submenu = NSMenu()
        submenu.autoenablesItems = false

        for option in app.tagDefinitions {
            let allTagged = targets.allSatisfy { app.tags(of: $0).contains(option.name) }
            let target = MenuAction {
                app.toggleTag(option.name, on: targets)
            }
            let menuItem = NSMenuItem(
                title: option.name,
                action: #selector(MenuAction.run(_:)),
                keyEquivalent: ""
            )
            menuItem.target = target
            menuItem.representedObject = target
            menuItem.image = tagImage(color: option.nsColor)
            menuItem.state = allTagged ? .on : .off
            submenu.addItem(menuItem)
        }

        submenu.addItem(.separator())

        let removeTarget = MenuAction {
            app.removeTags(from: targets)
        }
        let remove = NSMenuItem(
            title: L("Remove Tags"),
            action: #selector(MenuAction.run(_:)),
            keyEquivalent: ""
        )
        remove.target = removeTarget
        remove.representedObject = removeTarget
        remove.isEnabled = hasTags
        submenu.addItem(remove)

        let item = NSMenuItem(title: L("Tags"), action: nil, keyEquivalent: "")
        item.submenu = submenu
        menu.addItem(item)
    }

    private static func tagImage(color: NSColor) -> NSImage {
        NSImage(size: NSSize(width: 12, height: 12), flipped: false) { rect in
            color.setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 2, dy: 2)).fill()
            return true
        }
    }

    // MARK: - Servizi

    private static func addServicesSubmenu(to menu: NSMenu) {
        // NSApp.servicesMenu è già agganciato al menu principale: non può
        // essere usato come submenu di un altro menu. Ne creiamo una copia
        // per il menu contestuale, solo se ci sono servizi disponibili.
        guard let source = NSApp.servicesMenu, !source.items.isEmpty,
              let services = source.copy() as? NSMenu else {
            return
        }
        services.title = L("Services")

        let item = NSMenuItem(title: L("Services"), action: nil, keyEquivalent: "")
        item.submenu = services
        menu.addItem(item)
    }
}
