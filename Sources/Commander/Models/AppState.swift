import SwiftUI
import AppKit
import Darwin

// MARK: - Modelli di supporto

struct Favorite: Codable, Identifiable, Hashable {
    let path: String
    var name: String
    var symbol: String

    var id: String { path }
    var url: URL { URL(fileURLWithPath: path) }
}

struct Volume: Identifiable, Hashable {
    let url: URL
    let name: String
    let isRemovable: Bool
    let isLocal: Bool
    let isEjectable: Bool
    let isInternal: Bool

    var id: URL { url }
    var isNetwork: Bool { !isLocal }
    var canEject: Bool { isEjectable || isRemovable || isNetwork }

    var symbol: String {
        if isNetwork { return "network" }
        if isInternal { return "internaldrive" }
        return isRemovable ? "externaldrive.fill" : "externaldrive"
    }

    var ejectTitle: String {
        isNetwork ? L("Disconnect") : L("Eject")
    }
}

struct CloudLocation: Identifiable, Hashable {
    let url: URL
    let name: String
    let symbol: String
    var id: URL { url }
}

struct ErrorInfo: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

struct RenameRequest: Identifiable {
    let id = UUID()
    let url: URL
    var name: String
}

private enum Keys {
    static let showHidden = "pref.showHidden"
    static let foldersFirst = "pref.foldersFirst"
    static let confirmDelete = "pref.confirmDelete"
    static let viewMode = "pref.viewMode"
    static let showSidebar = "pref.showSidebar"
    static let showPreview = "pref.showPreview"
    static let dualPane = "pref.dualPane"
    static let favorites = "pref.favorites"
    static let session = "session.panes"

    // Impostazioni Finder
    static let startFolder = "pref.startFolder"
    static let openFoldersInNewTab = "pref.openFoldersInNewTab"
    static let showAllExtensions = "pref.showAllExtensions"
    static let warnExtensionChange = "pref.warnExtensionChange"
    static let warnEmptyTrash = "pref.warnEmptyTrash"
    static let useRelativeDates = "pref.useRelativeDates"
    static let showIconPreviews = "pref.showIconPreviews"
    static let searchSubfolders = "pref.searchSubfolders"
    static let showLibraryFolder = "pref.showLibraryFolder"
    static let sidebarFavorites = "pref.sidebar.favorites"
    static let sidebarCloud = "pref.sidebar.cloud"
    static let sidebarLocations = "pref.sidebar.locations"
    static let sidebarVolumes = "pref.sidebar.volumes"
    static let sidebarNetwork = "pref.sidebar.network"
    static let sidebarTrash = "pref.sidebar.trash"
    static let sidebarTags = "pref.sidebar.tags"
    static let tags = "pref.tags"
    static let showIconItemInfo = "pref.showIconItemInfo"
    static let showPathBar = "pref.showPathBar"
    static let showStatusBar = "pref.showStatusBar"
    static let showTabBar = "pref.showTabBar"
}

private struct SessionPane: Codable {
    var paths: [String]
    var selected: Int
}

// MARK: - AppState

final class AppState: ObservableObject {

    @Published var panes: [PaneState] = []
    @Published var activePaneID: UUID = UUID()

    // MARK: Preferenze

    @Published var showSidebar: Bool = UserDefaults.standard.object(forKey: Keys.showSidebar) as? Bool ?? true {
        didSet { UserDefaults.standard.set(showSidebar, forKey: Keys.showSidebar) }
    }

    @Published var showPreview: Bool = UserDefaults.standard.object(forKey: Keys.showPreview) as? Bool ?? false {
        didSet { UserDefaults.standard.set(showPreview, forKey: Keys.showPreview) }
    }

    @Published var startFolderPath: String =
        UserDefaults.standard.string(forKey: Keys.startFolder)
            ?? FileManager.default.homeDirectoryForCurrentUser.path {
        didSet { UserDefaults.standard.set(startFolderPath, forKey: Keys.startFolder) }
    }

    @Published var openFoldersInNewTab: Bool =
        UserDefaults.standard.object(forKey: Keys.openFoldersInNewTab) as? Bool ?? false {
        didSet { UserDefaults.standard.set(openFoldersInNewTab, forKey: Keys.openFoldersInNewTab) }
    }

    @Published var showAllExtensions: Bool =
        UserDefaults.standard.object(forKey: Keys.showAllExtensions) as? Bool ?? false {
        didSet {
            UserDefaults.standard.set(showAllExtensions, forKey: Keys.showAllExtensions)
            refreshAllTabs()
        }
    }

    @Published var warnExtensionChange: Bool =
        UserDefaults.standard.object(forKey: Keys.warnExtensionChange) as? Bool ?? true {
        didSet { UserDefaults.standard.set(warnExtensionChange, forKey: Keys.warnExtensionChange) }
    }

    @Published var warnEmptyTrash: Bool =
        UserDefaults.standard.object(forKey: Keys.warnEmptyTrash) as? Bool ?? true {
        didSet { UserDefaults.standard.set(warnEmptyTrash, forKey: Keys.warnEmptyTrash) }
    }

    @Published var useRelativeDates: Bool =
        UserDefaults.standard.object(forKey: Keys.useRelativeDates) as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(useRelativeDates, forKey: Keys.useRelativeDates)
            for pane in panes {
                for tab in pane.tabs { tab.objectWillChange.send() }
            }
        }
    }

    @Published var showIconItemInfo: Bool =
        UserDefaults.standard.object(forKey: Keys.showIconItemInfo) as? Bool ?? false {
        didSet {
            UserDefaults.standard.set(showIconItemInfo, forKey: Keys.showIconItemInfo)
            for pane in panes {
                for tab in pane.tabs { tab.objectWillChange.send() }
            }
        }
    }

    @Published var showIconPreviews: Bool =
        UserDefaults.standard.object(forKey: Keys.showIconPreviews) as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(showIconPreviews, forKey: Keys.showIconPreviews)
            for pane in panes {
                for tab in pane.tabs { tab.objectWillChange.send() }
            }
        }
    }

    @Published var showLibraryFolder: Bool =
        UserDefaults.standard.object(forKey: Keys.showLibraryFolder) as? Bool ?? false {
        didSet {
            UserDefaults.standard.set(showLibraryFolder, forKey: Keys.showLibraryFolder)
            refreshAllTabs()
        }
    }

    @Published var searchSubfolders: Bool =
        UserDefaults.standard.object(forKey: Keys.searchSubfolders) as? Bool ?? false {
        didSet {
            UserDefaults.standard.set(searchSubfolders, forKey: Keys.searchSubfolders)
            refreshAllTabs()
            for pane in panes {
                for tab in pane.tabs { tab.scheduleSearch() }
            }
        }
    }

    @Published var sidebarFavorites: Bool =
        UserDefaults.standard.object(forKey: Keys.sidebarFavorites) as? Bool ?? true {
        didSet { UserDefaults.standard.set(sidebarFavorites, forKey: Keys.sidebarFavorites) }
    }

    @Published var sidebarCloud: Bool =
        UserDefaults.standard.object(forKey: Keys.sidebarCloud) as? Bool ?? true {
        didSet { UserDefaults.standard.set(sidebarCloud, forKey: Keys.sidebarCloud) }
    }

    @Published var sidebarLocations: Bool =
        UserDefaults.standard.object(forKey: Keys.sidebarLocations) as? Bool ?? true {
        didSet { UserDefaults.standard.set(sidebarLocations, forKey: Keys.sidebarLocations) }
    }

    @Published var sidebarVolumes: Bool =
        UserDefaults.standard.object(forKey: Keys.sidebarVolumes) as? Bool ?? true {
        didSet { UserDefaults.standard.set(sidebarVolumes, forKey: Keys.sidebarVolumes) }
    }

    @Published var sidebarNetwork: Bool =
        UserDefaults.standard.object(forKey: Keys.sidebarNetwork) as? Bool ?? true {
        didSet { UserDefaults.standard.set(sidebarNetwork, forKey: Keys.sidebarNetwork) }
    }

    @Published var sidebarTrash: Bool =
        UserDefaults.standard.object(forKey: Keys.sidebarTrash) as? Bool ?? true {
        didSet { UserDefaults.standard.set(sidebarTrash, forKey: Keys.sidebarTrash) }
    }

    @Published var sidebarTags: Bool =
        UserDefaults.standard.object(forKey: Keys.sidebarTags) as? Bool ?? true {
        didSet { UserDefaults.standard.set(sidebarTags, forKey: Keys.sidebarTags) }
    }

    @Published var tagDefinitions: [FinderTagDefinition] = [] {
        didSet {
            if let data = try? JSONEncoder().encode(tagDefinitions) {
                UserDefaults.standard.set(data, forKey: Keys.tags)
            }
        }
    }

    @Published var showPathBar: Bool =
        UserDefaults.standard.object(forKey: Keys.showPathBar) as? Bool ?? true {
        didSet { UserDefaults.standard.set(showPathBar, forKey: Keys.showPathBar) }
    }

    @Published var showStatusBar: Bool =
        UserDefaults.standard.object(forKey: Keys.showStatusBar) as? Bool ?? true {
        didSet { UserDefaults.standard.set(showStatusBar, forKey: Keys.showStatusBar) }
    }

    @Published var showTabBar: Bool =
        UserDefaults.standard.object(forKey: Keys.showTabBar) as? Bool ?? true {
        didSet { UserDefaults.standard.set(showTabBar, forKey: Keys.showTabBar) }
    }

    @Published var dualPane: Bool = UserDefaults.standard.object(forKey: Keys.dualPane) as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(dualPane, forKey: Keys.dualPane)
            if !dualPane, let first = panes.first { activePaneID = first.id }
        }
    }

    @Published var showHidden: Bool = UserDefaults.standard.object(forKey: Keys.showHidden) as? Bool ?? false {
        didSet {
            UserDefaults.standard.set(showHidden, forKey: Keys.showHidden)
            refreshAllTabs()
            for pane in panes {
                for tab in pane.tabs { tab.scheduleSearch() }
            }
        }
    }

    @Published var foldersFirst: Bool = UserDefaults.standard.object(forKey: Keys.foldersFirst) as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(foldersFirst, forKey: Keys.foldersFirst)
            for pane in panes {
                for tab in pane.tabs { tab.objectWillChange.send() }
            }
        }
    }

    @Published var confirmDelete: Bool = UserDefaults.standard.object(forKey: Keys.confirmDelete) as? Bool ?? true {
        didSet { UserDefaults.standard.set(confirmDelete, forKey: Keys.confirmDelete) }
    }

    @Published var defaultViewMode: ViewMode = ViewMode(rawValue: UserDefaults.standard.string(forKey: Keys.viewMode) ?? "") ?? .icons {
        didSet {
            UserDefaults.standard.set(defaultViewMode.rawValue, forKey: Keys.viewMode)
            for pane in panes {
                for tab in pane.tabs { tab.viewMode = defaultViewMode }
            }
        }
    }

    let zoom = ZoomState()
    let fileOperations = FileOperationCenter()

    // MARK: Stato UI

    @Published var favorites: [Favorite] = []
    @Published var volumes: [Volume] = []
    @Published var cloudLocations: [CloudLocation] = []
    @Published var errorMessage: ErrorInfo?
    @Published var renameTarget: RenameRequest?
    @Published var activity: String?
    @Published var focusPathToken = 0
    @Published var focusSearchToken = 0
    @Published var showConnectSheet = false
    @Published var connectAddress = ""
    @Published var connectError: String?
    @Published var showViewOptions = false

    let network = NetworkBrowser()

    private let defaults = UserDefaults.standard
    private var persistWorkItem: DispatchWorkItem?
    private var sharingPicker: NSSharingServicePicker?
    private var pendingNetworkMount = false
    private var swipeMonitor: Any?
    private var extraButtonMonitor: Any?
    private var clickMonitor: Any?
    private var pendingDrag: (target: RowTargetView, event: NSEvent, point: NSPoint)?
    private var dragStarted = false
    private var typeAheadBuffer = ""
    private var typeAheadResetWork: DispatchWorkItem?
    private var scrollSwipeMonitor: Any?
    private var swipeAccumX: CGFloat = 0
    private var swipeAccumY: CGFloat = 0
    private var swipeTriggered = false

    // MARK: - Init

    init() {
        loadFavorites()
        loadTagDefinitions()
        refreshVolumes()
        refreshCloudLocations()
        setupPanes()
        if ProcessInfo.processInfo.environment["COMMANDER_HIDE_NETWORK"] != "1" {
            network.start()
        }

        KeyMonitor.shared.install()
        KeyMonitor.shared.handler = { [weak self] event in
            self?.handleKey(event) ?? false
        }
        installNavigationGestures()
        installClickMonitor()

        let center = NotificationCenter.default
        center.addObserver(forName: NSWorkspace.didMountNotification, object: nil, queue: .main) { [weak self] note in
            guard let self else { return }
            let mounted = note.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL
            self.refreshVolumes()
            if self.pendingNetworkMount {
                self.pendingNetworkMount = false
                if let mounted {
                    NSApp.activate(ignoringOtherApps: true)
                    self.go(to: mounted)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        self.closeFinderWindow(for: mounted)
                    }
                } else if let newest = self.volumes.first(where: { $0.isNetwork }) {
                    NSApp.activate(ignoringOtherApps: true)
                    self.go(to: newest.url)
                }
            }
        }
        center.addObserver(forName: NSWorkspace.didUnmountNotification, object: nil, queue: .main) { [weak self] _ in
            self?.refreshVolumes()
        }
        center.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            self?.persistSession()
        }

        applyDebugEnvironment()
    }

    deinit {
        network.stop()
        if let swipeMonitor { NSEvent.removeMonitor(swipeMonitor) }
        if let extraButtonMonitor { NSEvent.removeMonitor(extraButtonMonitor) }
        if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
        if let scrollSwipeMonitor { NSEvent.removeMonitor(scrollSwipeMonitor) }
    }

    private func setupPanes() {
        let left = PaneState()
        let right = PaneState()
        panes = [left, right]
        activePaneID = left.id

        let saved = loadSession()
        let home = FileManager.default.homeDirectoryForCurrentUser
        let downloads = home.appendingPathComponent("Downloads")

        if let override = ProcessInfo.processInfo.environment["COMMANDER_START_PATH"], !override.isEmpty {
            let url = URL(fileURLWithPath: (override as NSString).expandingTildeInPath)
            left.configure(app: self, paths: [url], selected: 0)
            right.configure(app: self, paths: [url], selected: 0)
        } else if let saved, saved.count >= 2 {
            left.configure(
                app: self,
                paths: saved[0].paths.map { URL(fileURLWithPath: $0) },
                selected: saved[0].selected
            )
            right.configure(
                app: self,
                paths: saved[1].paths.map { URL(fileURLWithPath: $0) },
                selected: saved[1].selected
            )
        } else {
            let startURL = URL(fileURLWithPath: (startFolderPath as NSString).expandingTildeInPath)
            let initial = FileSystem.fm.fileExists(atPath: startURL.path) ? startURL : home
            left.configure(app: self, paths: [initial], selected: 0)
            let second: URL
            if initial.standardizedFileURL == downloads.standardizedFileURL {
                second = home
            } else {
                second = FileSystem.fm.fileExists(atPath: downloads.path) ? downloads : home
            }
            right.configure(app: self, paths: [second], selected: 0)
        }
    }

    // MARK: - Pannello attivo

    var activePane: PaneState? {
        panes.first(where: { $0.id == activePaneID }) ?? panes.first
    }

    var activeTab: BrowserTab? { activePane?.activeTab }

    var visiblePanes: [PaneState] {
        dualPane ? panes : Array(panes.prefix(1))
    }

    func activate(_ pane: PaneState) {
        guard pane.id != activePaneID else { return }
        activePaneID = pane.id
    }

    func activateOtherPane() {
        guard dualPane, panes.count > 1 else { return }
        if let current = panes.firstIndex(where: { $0.id == activePaneID }) {
            activePaneID = panes[(current + 1) % panes.count].id
        }
    }

    func focusPane(index: Int) {
        guard index < panes.count else { return }
        if index == 1 && !dualPane { dualPane = true }
        activePaneID = panes[index].id
    }

    // MARK: - Schede

    func newTab(at url: URL? = nil) {
        activePane?.newTab(at: url)
    }

    func closeTab() {
        activePane?.closeActiveTab()
    }

    func nextTab() {
        activePane?.nextTab()
    }

    func previousTab() {
        activePane?.previousTab()
    }

    // MARK: - Navigazione

    func goBack() { activeTab?.goBack() }
    func goForward() { activeTab?.goForward() }
    func goUp() { activeTab?.goUp() }

    private var lastSwipeNavigation = Date.distantPast

    func swipeBack() {
        let now = Date()
        guard now.timeIntervalSince(lastSwipeNavigation) > 0.3 else { return }
        lastSwipeNavigation = now
        goBack()
    }

    func swipeForward() {
        let now = Date()
        guard now.timeIntervalSince(lastSwipeNavigation) > 0.3 else { return }
        lastSwipeNavigation = now
        goForward()
    }

    func go(to url: URL) {
        activeTab?.navigate(to: url)
    }

    func focusPathBar() {
        focusPathToken += 1
    }

    func focusSearch() {
        activeTab?.showsSearch = true
        focusSearchToken += 1
    }

    func setViewMode(_ mode: ViewMode) {
        activeTab?.viewMode = mode
        objectWillChange.send()
    }

    func ejectCurrentVolume() {
        guard let folder = activeTab?.currentFolder else { return }
        let path = folder.standardizedFileURL.path
        guard let volume = volumes.first(where: {
            $0.canEject && path.hasPrefix($0.url.standardizedFileURL.path)
        }) else { return }
        eject(volume)
    }

    var canEjectCurrentVolume: Bool {
        guard let folder = activeTab?.currentFolder else { return false }
        let path = folder.standardizedFileURL.path
        return volumes.contains { $0.canEject && path.hasPrefix($0.url.standardizedFileURL.path) }
    }

    func openSelection() {
        activeTab?.openSelection()
    }

    /// ⌘I / ⌥⌘I: pannello Informazioni per la selezione o la cartella corrente.
    func getInfo() {
        guard let tab = activeTab else { return }
        let urls = tab.selection.isEmpty
            ? [tab.currentFolder]
            : FileSystem.existingItems(at: Array(tab.selection))
        guard !urls.isEmpty else { return }

        // Per un singolo elemento usa la vera finestra Informazioni di Finder.
        // Per selezioni multiple Finder non offre un equivalente AppleScript
        // affidabile, quindi mostriamo il riepilogo nativo.
        if urls.count == 1, FileInfoPanelController.openFinderInfo(for: urls[0]) {
            return
        }
        FileInfoPanelController.shared.show(urls: urls)
    }

    func makeAliasSelection() {
        guard let tab = activeTab, !tab.selection.isEmpty else { return }
        makeAlias(Array(tab.selection))
    }

    func closeCurrentTabOrWindow() {
        if let pane = activePane, pane.tabs.count > 1 {
            pane.closeActiveTab()
        } else {
            NSApp.keyWindow?.performClose(nil)
        }
    }

    func emptyTrash() {
        let trash = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".Trash")
        if warnEmptyTrash {
            let alert = NSAlert()
            alert.messageText = L("Do you want to empty the Trash?")
            alert.informativeText = L("This action cannot be undone.")
            alert.alertStyle = .warning
            alert.addButton(withTitle: L("Empty Trash"))
            alert.addButton(withTitle: L("Cancel"))
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }

        run(L("Emptying Trash…"), {
            let items = try FileManager.default.contentsOfDirectory(
                at: trash,
                includingPropertiesForKeys: nil
            )
            for item in items {
                try FileManager.default.removeItem(at: item)
            }
        }, onSuccess: {
            self.refreshAllTabs()
        })
    }

    func movePasteHere() {
        guard let tab = activeTab else { return }
        let (urls, _) = FileClipboard.read()
        guard !urls.isEmpty else { return }
        let destination = tab.currentFolder
        let movable = urls.filter {
            $0.deletingLastPathComponent().standardizedFileURL != destination.standardizedFileURL
        }
        guard !movable.isEmpty else { return }

        fileOperations.move(movable, to: destination) { [weak self] result in
            if case .success = result {
                NSPasteboard.general.clearContents()
            }
            self?.finishFileOperation(result)
        }
    }

    func toggleToolbar() {
        guard let window = NSApp.keyWindow else { return }
        window.toolbar?.isVisible.toggle()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            AppDelegate.normalizeWindowButtons(window)
        }
    }

    func zoomIconsIn() {
        zoom.iconSize = min(160, zoom.iconSize + 8)
    }

    func zoomIconsOut() {
        zoom.iconSize = max(48, zoom.iconSize - 8)
    }

    func resetIconSize() {
        zoom.iconSize = 76
    }

    func goToUtilities() {
        let modern = URL(fileURLWithPath: "/System/Applications/Utilities")
        go(to: FileManager.default.fileExists(atPath: modern.path)
            ? modern
            : URL(fileURLWithPath: "/Applications/Utilities"))
    }

    func goToComputer() {
        go(to: URL(fileURLWithPath: "/"))
    }

    func goToICloud() {
        let iCloud = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
        if FileManager.default.fileExists(atPath: iCloud.path) {
            go(to: iCloud)
        } else {
            refreshCloudLocations()
            if let first = cloudLocations.first {
                go(to: first.url)
            }
        }
    }

    func goToNetwork() {
        beginConnectToServer()
    }

    func showSettings() {
        // Preferisce la voce di menu SwiftUI: il selettore storico
        // showSettingsWindow: può essere gestito senza aprire la finestra.
        if let appMenu = NSApp.mainMenu?.items.first?.submenu,
           let settingsItem = appMenu.items.first(where: {
               $0.title == L("Settings…") || $0.title == "Settings…" || $0.title == "Impostazioni…"
           }),
           let action = settingsItem.action {
            NSApp.sendAction(action, to: settingsItem.target, from: settingsItem)
            return
        }

        if NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) { return }
        NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
    }

    func showTag(_ tag: FinderTagDefinition) {
        guard let pane = activePane else { return }
        let home = FileManager.default.homeDirectoryForCurrentUser
        guard let tab = pane.newTab(at: home) else { return }
        tab.viewMode = .list
        tab.applyTagFilter(tag.name)
    }

    func openInOtherPane(_ url: URL) {
        guard panes.count > 1 else { return }
        let other = panes.first(where: { $0.id != activePaneID }) ?? panes[1]
        other.activeTab?.navigate(to: url)
        if !dualPane { dualPane = true }
        activePaneID = other.id
    }

    func revealInFinder() {
        guard let tab = activeTab else { return }
        let urls = tab.selection.isEmpty ? [tab.currentFolder] : Array(tab.selection)
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    func openInTerminal() {
        guard let folder = activeTab?.currentFolder else { return }
        openTerminal(at: folder)
    }

    func copyPath(_ url: URL) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.path, forType: .string)
    }

    func openTerminal(at url: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", "Terminal", url.path]
        try? process.run()
    }

    func openTerminalTab(at url: URL) {
        let shellPath = url.path.replacingOccurrences(of: "'", with: "'\\''")
        let source = """
        tell application "Terminal"
            activate
            if (count of windows) > 0 then
                do script "cd '\(shellPath)'" in front window
            else
                do script "cd '\(shellPath)'"
            end if
        end tell
        """
        guard let script = NSAppleScript(source: source) else {
            openTerminal(at: url)
            return
        }
        var error: NSDictionary?
        _ = script.executeAndReturnError(&error)
        if error != nil {
            openTerminal(at: url)
        }
    }

    func customizeFolder(_ url: URL) {
        FolderCustomizationPanelController.shared.show(url: url)
    }

    // MARK: - Selezione

    func selectAll() {
        activeTab?.selectAll()
    }

    func clearSelection() {
        activeTab?.clearSelection()
    }

    // MARK: - Condivisione

    func shareSelection() {
        guard let tab = activeTab else { return }
        let urls = tab.selection.isEmpty
            ? [tab.currentFolder]
            : FileSystem.existingItems(at: Array(tab.selection))
        guard !urls.isEmpty, let view = NSApp.keyWindow?.contentView else { return }

        let picker = NSSharingServicePicker(items: urls)
        sharingPicker = picker
        let rect = NSRect(x: view.bounds.midX, y: view.bounds.maxY - 6, width: 1, height: 1)
        picker.show(relativeTo: rect, of: view, preferredEdge: .minY)
    }

    // MARK: - Appunti e file

    func copySelection() {
        guard let tab = activeTab, !tab.selection.isEmpty else { return }
        FileClipboard.write(Array(tab.selection), cut: false)
    }

    func cutSelection() {
        guard let tab = activeTab, !tab.selection.isEmpty else { return }
        FileClipboard.write(Array(tab.selection), cut: true)
    }

    func paste() {
        guard let tab = activeTab else { return }
        paste(into: tab.currentFolder)
    }

    func paste(into destination: URL) {
        let (urls, cut) = FileClipboard.read()
        guard !urls.isEmpty else { return }

        if cut {
            let movable = urls.filter {
                $0.deletingLastPathComponent().standardizedFileURL != destination.standardizedFileURL
            }
            guard !movable.isEmpty else { return }

            fileOperations.move(movable, to: destination) { [weak self] result in
                if case .success = result {
                    NSPasteboard.general.clearContents()
                }
                self?.finishFileOperation(result)
            }
        } else {
            fileOperations.copy(urls, to: destination) { [weak self] result in
                self?.finishFileOperation(result)
            }
        }
    }

    private func finishFileOperation(_ result: Result<Void, Error>, onSuccess: (() -> Void)? = nil) {
        switch result {
        case .success:
            onSuccess?()
        case .failure(let error):
            if !(error is FileOperationCancelled) {
                present(error)
            }
        }
        refreshAllTabs()
    }

    func trashSelection() {
        guard let tab = activeTab, !tab.selection.isEmpty else { return }
        trash(Array(tab.selection))
        tab.selection.removeAll()
    }

    func trash(_ urls: [URL]) {
        let valid = FileSystem.existingItems(at: urls)
        guard !valid.isEmpty else { return }
        run(L("Moving to Trash…"), {
            try FileSystem.trash(valid)
        }, onSuccess: {
            for pane in self.panes {
                for tab in pane.tabs {
                    tab.selection.subtract(valid)
                }
            }
        })
    }

    func deletePermanently() {
        guard let tab = activeTab, !tab.selection.isEmpty else { return }
        let urls = FileSystem.existingItems(at: Array(tab.selection))
        guard !urls.isEmpty else { return }

        if confirmDelete {
            let alert = NSAlert()
            if urls.count == 1 {
                alert.messageText = String(format: L("Do you want to delete “%@” permanently?"), urls[0].lastPathComponent)
            } else {
                alert.messageText = String(format: L("Do you want to delete %d items permanently?"), urls.count)
            }
            alert.informativeText = L("This action cannot be undone.")
            alert.alertStyle = .warning
            alert.addButton(withTitle: L("Delete"))
            alert.addButton(withTitle: L("Cancel"))
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }

        run(L("Deleting…"), {
            try FileSystem.deletePermanently(urls)
        }, onSuccess: {
            tab.selection.removeAll()
        })
    }

    func duplicateSelection() {
        guard let tab = activeTab, !tab.selection.isEmpty else { return }
        duplicate(Array(tab.selection))
    }

    func duplicate(_ urls: [URL]) {
        let valid = FileSystem.existingItems(at: urls)
        guard !valid.isEmpty, let folder = valid.first?.deletingLastPathComponent() else { return }
        fileOperations.copy(valid, to: folder) { [weak self] result in
            self?.finishFileOperation(result)
        }
    }

    // MARK: - Azioni Finder (Comprimi, Alias, Tag)

    func compress(_ urls: [URL]) {
        let valid = FileSystem.existingItems(at: urls)
        guard !valid.isEmpty, let first = valid.first else { return }
        let parent = first.deletingLastPathComponent()
        let sameParent = valid.allSatisfy {
            $0.deletingLastPathComponent().standardizedFileURL == parent.standardizedFileURL
        }

        let base: String
        if valid.count == 1 {
            let stem = first.deletingPathExtension().lastPathComponent
            base = stem.isEmpty ? first.lastPathComponent : stem
        } else {
            base = L("Archive")
        }

        var destination = parent.appendingPathComponent("\(base).zip")
        var index = 2
        while FileManager.default.fileExists(atPath: destination.path) {
            destination = parent.appendingPathComponent("\(base) \(index).zip")
            index += 1
        }

        let names = valid.map { sameParent ? $0.lastPathComponent : $0.path }
        let archiveName = destination.lastPathComponent
        let flatten = !sameParent
        let firstIsDirectory = (try? first.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false

        run(L("Compressing…"), {
            let process = Process()
            if valid.count == 1 {
                process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
                process.currentDirectoryURL = parent
                var arguments = ["-c", "-k", "--sequesterRsrc"]
                if firstIsDirectory {
                    arguments.append("--keepParent")
                }
                arguments.append(contentsOf: [first.lastPathComponent, destination.path])
                process.arguments = arguments
            } else {
                process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
                process.currentDirectoryURL = parent
                var arguments = ["-r", "-q", "-y"]
                if flatten { arguments.append("-j") }
                arguments.append(archiveName)
                arguments.append(contentsOf: names)
                process.arguments = arguments
            }

            let stderr = Pipe()
            process.standardError = stderr
            try process.run()
            let data = stderr.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                let detail = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                throw NSError(
                    domain: "Commander",
                    code: Int(process.terminationStatus),
                    userInfo: [NSLocalizedDescriptionKey: detail.isEmpty
                        ? L("Could not compress the selected items.")
                        : detail]
                )
            }
        }, onSuccess: {
            self.refreshAllTabs()
            self.activeTab?.selection = [destination]
        })
    }

    func makeAlias(_ urls: [URL]) {
        let valid = FileSystem.existingItems(at: urls)
        guard !valid.isEmpty else { return }

        run(L("Creating Alias…"), {
            for url in valid {
                let ext = url.pathExtension
                let stem = url.deletingPathExtension().lastPathComponent
                let base = ext.isEmpty ? "\(stem) alias" : "\(stem) alias.\(ext)"
                let parent = url.deletingLastPathComponent()
                var destination = parent.appendingPathComponent(base)
                var index = 2
                while FileManager.default.fileExists(atPath: destination.path) {
                    destination = parent.appendingPathComponent(
                        ext.isEmpty ? "\(stem) alias \(index)" : "\(stem) alias \(index).\(ext)"
                    )
                    index += 1
                }
                try FileManager.default.createSymbolicLink(at: destination, withDestinationURL: url)
            }
        }, onSuccess: {
            self.refreshAllTabs()
        })
    }

    func toggleTag(_ name: String, on urls: [URL]) {
        let valid = FileSystem.existingItems(at: urls)
        guard !valid.isEmpty else { return }
        let allTagged = valid.allSatisfy { tags(of: $0).contains(name) }

        for url in valid {
            var tags = tags(of: url)
            if allTagged {
                tags.removeAll { $0 == name }
            } else if !tags.contains(name) {
                tags.append(name)
            }
            do {
                try writeTags(tags, to: url)
            } catch {
                present(error)
                return
            }
        }
        refreshAllTabs()
    }

    func removeTags(from urls: [URL]) {
        let valid = FileSystem.existingItems(at: urls)
        guard !valid.isEmpty else { return }
        for url in valid {
            do {
                try writeTags([], to: url)
            } catch {
                present(error)
                return
            }
        }
        refreshAllTabs()
    }

    func tags(of url: URL) -> [String] {
        (try? url.resourceValues(forKeys: [.tagNamesKey]))?.tagNames ?? []
    }

    /// Scrive i Finder tag nell'xattr usato da Spotlight/Finder. Il setter di
    /// URLResourceValues per tagNames è disponibile solo da macOS 26, mentre
    /// l'app supporta anche versioni precedenti.
    private func writeTags(_ tags: [String], to url: URL) throws {
        let data = try PropertyListSerialization.data(
            fromPropertyList: tags,
            format: .binary,
            options: 0
        )
        let result: Int32 = data.withUnsafeBytes { buffer in
            setxattr(
                url.path,
                "com.apple.metadata:_kMDItemUserTags",
                buffer.baseAddress,
                buffer.count,
                0,
                0
            )
        }
        guard result == 0 else {
            throw NSError(
                domain: NSPOSIXErrorDomain,
                code: Int(errno),
                userInfo: [NSLocalizedDescriptionKey: String(cString: strerror(errno))]
            )
        }
    }

    func createFolder() {
        guard let tab = activeTab else { return }
        createFolder(in: tab.currentFolder)
    }

    func createFolder(in directory: URL) {
        do {
            let url = try FileSystem.createFolder(in: directory)
            refreshAllTabs()
            activeTab?.selection = [url]
            beginRename(url)
            schedulePersist()
        } catch {
            present(error)
        }
    }

    func createFile() {
        guard let tab = activeTab else { return }
        createFile(in: tab.currentFolder)
    }

    func createFile(in directory: URL) {
        do {
            let url = try FileSystem.createFile(in: directory)
            refreshAllTabs()
            activeTab?.selection = [url]
            beginRename(url)
        } catch {
            present(error)
        }
    }

    func beginRename(_ url: URL) {
        renameTarget = RenameRequest(url: url, name: url.lastPathComponent)
    }

    func renameSelection() {
        guard let item = activeTab?.renameTarget() else { return }
        beginRename(item.url)
    }

    func commitRename(_ request: RenameRequest, newName: String) {
        let oldExtension = request.url.pathExtension
        let newExtension = (newName as NSString).pathExtension
        if warnExtensionChange,
           oldExtension.caseInsensitiveCompare(newExtension) != .orderedSame,
           !oldExtension.isEmpty || !newExtension.isEmpty {
            let alert = NSAlert()
            alert.messageText = String(
                format: L("Are you sure you want to change the extension from “%@” to “%@”?"),
                oldExtension.isEmpty ? L("none") : oldExtension,
                newExtension.isEmpty ? L("none") : newExtension
            )
            alert.informativeText = L("The file may no longer open with the same application.")
            alert.alertStyle = .warning
            alert.addButton(withTitle: L("Change"))
            alert.addButton(withTitle: L("Cancel"))
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }

        do {
            let newURL = try FileSystem.rename(request.url, to: newName)
            renameTarget = nil
            refreshAllTabs()
            activeTab?.selection = [newURL]
        } catch {
            renameTarget = nil
            present(error)
        }
    }

    func moveOrCopy(_ urls: [URL], to destination: URL, copy: Bool) {
        var valid = FileSystem.existingItems(at: urls).filter {
            $0.standardizedFileURL != destination.standardizedFileURL
        }
        if !copy {
            valid = valid.filter {
                $0.deletingLastPathComponent().standardizedFileURL != destination.standardizedFileURL
            }
        }
        guard !valid.isEmpty else { return }

        if copy {
            fileOperations.copy(valid, to: destination) { [weak self] result in
                self?.finishFileOperation(result)
            }
        } else {
            fileOperations.move(valid, to: destination) { [weak self] result in
                self?.finishFileOperation(result)
            }
        }
    }

    private func run(_ label: String, _ operation: @escaping () throws -> Void, onSuccess: (() -> Void)? = nil) {
        activity = label
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Result { try operation() }
            DispatchQueue.main.async {
                guard let self else { return }
                self.activity = nil
                switch result {
                case .success:
                    onSuccess?()
                    self.refreshAllTabs()
                case .failure(let error):
                    self.present(error)
                }
            }
        }
    }

    func refreshAllTabs() {
        for pane in panes {
            for tab in pane.tabs { tab.refresh() }
        }
    }

    func present(_ error: Error) {
        errorMessage = ErrorInfo(title: L("Operation Failed"), message: error.localizedDescription)
    }

    // MARK: - Anteprima e Quick Look

    func toggleQuickLook() {
        guard let tab = activeTab else { return }
        QuickLookController.shared.toggle(urls: tab.previewItems)
    }

    // MARK: - Volumi, rete, cloud

    func refreshVolumes() {
        let keys: [URLResourceKey] = [
            .volumeNameKey, .volumeIsRemovableKey, .volumeIsInternalKey,
            .volumeIsLocalKey, .volumeIsEjectableKey, .volumeIsRootFileSystemKey
        ]
        let urls = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: keys,
            options: [.skipHiddenVolumes]
        ) ?? [URL(fileURLWithPath: "/")]

        var result: [Volume] = []
        for url in urls {
            let values = try? url.resourceValues(forKeys: Set(keys))
            let name = values?.volumeName ?? url.lastPathComponent
            let isRoot = values?.volumeIsRootFileSystem ?? (url.path == "/")
            let internalDisk = values?.volumeIsInternal ?? false
            result.append(Volume(
                url: url,
                name: name.isEmpty ? "Macintosh HD" : name,
                isRemovable: values?.volumeIsRemovable ?? false,
                isLocal: values?.volumeIsLocal ?? true,
                isEjectable: values?.volumeIsEjectable ?? false,
                isInternal: internalDisk || isRoot
            ))
        }
        if !result.contains(where: { $0.url.path == "/" }) {
            result.insert(
                Volume(
                    url: URL(fileURLWithPath: "/"),
                    name: "Macintosh HD",
                    isRemovable: false,
                    isLocal: true,
                    isEjectable: false,
                    isInternal: true
                ),
                at: 0
            )
        }

        if ProcessInfo.processInfo.environment["COMMANDER_HIDE_NETWORK"] == "1" {
            result.removeAll { $0.isNetwork }
        }

        volumes = result.sorted { a, b in
            if a.url.path == "/" { return true }
            if b.url.path == "/" { return false }
            if a.isNetwork != b.isNetwork { return !a.isNetwork }
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        }
    }

    func refreshCloudLocations() {
        let fm = FileManager.default
        var result: [CloudLocation] = []
        let home = fm.homeDirectoryForCurrentUser

        let iCloud = home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
        if fm.fileExists(atPath: iCloud.path) {
            result.append(CloudLocation(url: iCloud, name: L("iCloud Drive"), symbol: "icloud"))
        }

        let cloudStorage = home.appendingPathComponent("Library/CloudStorage")
        if let providers = try? fm.contentsOfDirectory(
            at: cloudStorage,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) {
            for provider in providers {
                guard (try? provider.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else { continue }
                let raw = provider.lastPathComponent
                let name: String
                if raw.hasPrefix("GoogleDrive-") { name = "Google Drive" }
                else if raw.hasPrefix("OneDrive-") { name = "OneDrive" }
                else if raw.hasPrefix("Dropbox") { name = "Dropbox" }
                else if raw.hasPrefix("Box") { name = "Box" }
                else { name = raw }
                result.append(CloudLocation(url: provider, name: name, symbol: "cloud"))
            }
        }
        cloudLocations = result
    }

    func eject(_ volume: Volume) {
        let volumePath = volume.url.standardizedFileURL.path
        do {
            try NSWorkspace.shared.unmountAndEjectDevice(at: volume.url)
            refreshVolumes()

            let home = FileManager.default.homeDirectoryForCurrentUser
            for pane in panes {
                for tab in pane.tabs {
                    if tab.currentFolder.standardizedFileURL.path.hasPrefix(volumePath) {
                        tab.navigate(to: home)
                    }
                }
            }
        } catch {
            present(error)
        }
    }

    @discardableResult
    func connectToServer(_ address: String) -> Bool {
        var value = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return false }
        if !value.contains("://") {
            value = "smb://" + value
        }

        guard let url = URL(string: value),
              let host = url.host,
              !host.isEmpty,
              !host.contains(" ") else {
            connectError = L("The server address is not valid.")
            return false
        }

        pendingNetworkMount = true
        connectError = nil
        showConnectSheet = false
        connectAddress = ""

        // Il mount avviene tramite Finder senza aprire una finestra Finder.
        // Lo eseguiamo fuori dal main thread: l'eventuale prompt di Automazione
        // o di autenticazione non deve bloccare l'interfaccia.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let mounted = self.mountVolumeWithFinder(value)
            DispatchQueue.main.async {
                guard self.pendingNetworkMount else { return }
                if mounted {
                    self.scheduleNetworkMountTimeout()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        guard self.pendingNetworkMount else { return }
                        self.pendingNetworkMount = false
                        if let volume = self.volumes.first(where: { $0.isNetwork }) {
                            NSApp.activate(ignoringOtherApps: true)
                            self.go(to: volume.url)
                        }
                    }
                } else {
                    self.pendingNetworkMount = false
                    self.connectAddress = value
                    self.connectError = L("The server could not be reached.")
                    self.showConnectSheet = true
                }
            }
        }
        return true
    }

    private func scheduleNetworkMountTimeout() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            self?.pendingNetworkMount = false
        }
    }

    private func mountVolumeWithFinder(_ address: String) -> Bool {
        let escaped = address
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let source = """
        tell application "Finder"
            mount volume "\(escaped)"
        end tell
        """
        guard let script = NSAppleScript(source: source) else { return false }
        var error: NSDictionary?
        _ = script.executeAndReturnError(&error)
        return error == nil
    }

    private func closeFinderWindow(for url: URL) {
        let escaped = url.path
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let source = """
        tell application "Finder"
            set thePath to POSIX path of (POSIX file "\(escaped)" as alias)
            repeat with w in windows
                try
                    if POSIX path of (target of w as alias) is thePath then close w
                end try
            end repeat
        end tell
        """
        guard let script = NSAppleScript(source: source) else { return }
        var error: NSDictionary?
        _ = script.executeAndReturnError(&error)
    }

    func connect(to server: NetworkServer) {
        guard server.hasValidHost else {
            connectAddress = "\(server.scheme)://"
            connectError = L("The server could not be resolved. Enter its address manually.")
            showConnectSheet = true
            return
        }

        // NFS richiede sempre il percorso dell'export: apriamo il foglio
        // invece di tentare un mount che fallirebbe.
        if server.scheme == "nfs" {
            connectAddress = "nfs://\(server.connectHost)/"
            connectError = L("For NFS, add the export path to the address.")
            showConnectSheet = true
            return
        }

        let address = "\(server.scheme)://\(server.connectHost)"
        if !connectToServer(address) {
            connectAddress = address
            showConnectSheet = true
        }
    }

    /// Apre il foglio di connessione pulito (pulsante “Connetti al server…”).
    func beginConnectToServer() {
        connectAddress = ""
        connectError = nil
        showConnectSheet = true
    }

    // MARK: - Preferiti

    func loadFavorites() {
        if let data = defaults.data(forKey: Keys.favorites),
           let saved = try? JSONDecoder().decode([Favorite].self, from: data) {
            favorites = saved
        } else {
            favorites = Self.defaultFavorites
        }
    }

    func loadTagDefinitions() {
        if let data = defaults.data(forKey: Keys.tags),
           let saved = try? JSONDecoder().decode([FinderTagDefinition].self, from: data) {
            tagDefinitions = saved
        } else {
            tagDefinitions = FinderTagPalette.defaultDefinitions()
        }
    }

    func resetTagDefinitions() {
        tagDefinitions = FinderTagPalette.defaultDefinitions()
    }

    func resetSession() {
        defaults.removeObject(forKey: Keys.session)
        setupPanes()
        schedulePersist()
    }

    func chooseStartFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = L("Choose")
        panel.message = L("Choose the folder to open in new windows.")
        if panel.runModal() == .OK, let url = panel.url {
            startFolderPath = url.path
        }
    }

    static var defaultFavorites: [Favorite] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            Favorite(path: home.path, name: L("Home"), symbol: "house.fill"),
            Favorite(path: home.appendingPathComponent("Desktop").path, name: L("Desktop"), symbol: "display"),
            Favorite(path: home.appendingPathComponent("Documents").path, name: L("Documents"), symbol: "doc.fill"),
            Favorite(path: home.appendingPathComponent("Downloads").path, name: L("Downloads"), symbol: "arrow.down.circle.fill"),
            Favorite(path: "/Applications", name: L("Applications"), symbol: "square.grid.2x2.fill"),
            Favorite(path: home.appendingPathComponent("Movies").path, name: L("Movies"), symbol: "film.fill"),
            Favorite(path: home.appendingPathComponent("Music").path, name: L("Music"), symbol: "music.note"),
            Favorite(path: home.appendingPathComponent("Pictures").path, name: L("Pictures"), symbol: "photo.fill")
        ]
    }

    func addFavorite(_ url: URL) {
        guard !favorites.contains(where: { $0.path == url.path }) else { return }
        let name = FileManager.default.displayName(atPath: url.path)
        favorites.append(Favorite(path: url.path, name: name, symbol: "folder.fill"))
        saveFavorites()
    }

    func removeFavorite(_ favorite: Favorite) {
        favorites.removeAll { $0.id == favorite.id }
        saveFavorites()
    }

    func moveFavorite(from source: IndexSet, to destination: Int) {
        favorites.move(fromOffsets: source, toOffset: destination)
        saveFavorites()
    }

    func moveFavorite(from source: Int, to target: Int) {
        guard favorites.indices.contains(source), favorites.indices.contains(target), source != target else { return }
        let item = favorites.remove(at: source)
        let insertion = target > source ? target - 1 : target
        favorites.insert(item, at: min(insertion, favorites.count))
        saveFavorites()
    }

    private func saveFavorites() {
        if let data = try? JSONEncoder().encode(favorites) {
            defaults.set(data, forKey: Keys.favorites)
        }
    }

    // MARK: - Sessione

    func schedulePersist() {
        persistWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.persistSession()
        }
        persistWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    func persistSession() {
        let session = panes.map { pane in
            SessionPane(
                paths: pane.tabs.map(\.persistedPath),
                selected: pane.activeIndex ?? 0
            )
        }
        if let data = try? JSONEncoder().encode(session) {
            defaults.set(data, forKey: Keys.session)
        }
    }

    private func loadSession() -> [SessionPane]? {
        guard let data = defaults.data(forKey: Keys.session) else { return nil }
        return try? JSONDecoder().decode([SessionPane].self, from: data)
    }

    // MARK: - Tastiera

    private func handleKey(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection([.command, .option, .shift, .control])

        if flags.contains(.command) {
            let chars = event.charactersIgnoringModifiers?.lowercased() ?? ""

            if event.keyCode == 51 || event.keyCode == 117 {
                if flags.contains(.option) {
                    deletePermanently()
                    return true
                }
                if flags.contains(.shift) {
                    emptyTrash()
                    return true
                }
                trashSelection()
                return true
            }

            switch chars {
            case "c":
                if flags == .command { copySelection(); return true }
            case "x":
                if flags == .command { cutSelection(); return true }
            case "v":
                if flags == .command { paste(); return true }
                if flags == [.command, .option] { movePasteHere(); return true }
            case "a":
                if flags == .command { selectAll(); return true }
                if flags == [.command, .control] { makeAliasSelection(); return true }
            case "d":
                if flags == .command { duplicateSelection(); return true }
            case "i":
                if flags == .command || flags == [.command, .option] {
                    getInfo()
                    return true
                }
            case "y":
                if flags == .command { toggleQuickLook(); return true }
            case "w":
                if flags == .command { closeCurrentTabOrWindow(); return true }
            case "l":
                if flags == .command { focusPathBar(); return true }
            case "r":
                if flags == .command { refreshAllTabs(); return true }
            case "t":
                if flags == .command { newTab(); return true }
                if flags == [.command, .option] { toggleToolbar(); return true }
            case "g":
                if flags == [.command, .shift] { focusPathBar(); return true }
            case "n":
                if flags == [.command, .shift] { createFolder(); return true }
            case "k":
                if flags == .command { beginConnectToServer(); return true }
            case "e":
                if flags == .command { ejectCurrentVolume(); return true }
            case "o":
                if flags == .command { openSelection(); return true }
            case "f":
                if flags == .command { focusSearch(); return true }
            case "p":
                if flags == [.command, .option] { showPreview.toggle(); return true }
            case "/":
                if flags == .command { showStatusBar.toggle(); return true }
            case ".":
                if flags == [.command, .shift] { showHidden.toggle(); return true }
            case "[":
                if flags == [.command, .shift] { previousTab(); return true }
                if flags == .command { goBack(); return true }
            case "]":
                if flags == [.command, .shift] { nextTab(); return true }
                if flags == .command { goForward(); return true }
            case "+", "=":
                if flags.contains(.command) { zoomIconsIn(); return true }
            case "-":
                if flags == .command { zoomIconsOut(); return true }
            case "0":
                if flags == .command { resetIconSize(); return true }
            default:
                break
            }

            switch event.keyCode {
            case 126:
                if flags.contains(.shift) { openEnclosingInNewTab() } else { goUp() }
                return true
            case 125: openSelection(); return true
            case 123: goBack(); return true
            case 124: goForward(); return true
            default: break
            }
            return false
        }

        guard flags.isEmpty || flags == .shift else { return false }

        if flags == .shift {
            switch event.keyCode {
            case 125:
                moveSelection(delta: verticalStep, extend: true)
                return true
            case 126:
                moveSelection(delta: -verticalStep, extend: true)
                return true
            case 123:
                activeTab?.moveSelection(by: -1, extend: true)
                return true
            case 124:
                activeTab?.moveSelection(by: 1, extend: true)
                return true
            case 116:
                activeTab?.moveSelection(by: -10, extend: true)
                return true
            case 121:
                activeTab?.moveSelection(by: 10, extend: true)
                return true
            case 115:
                activeTab?.moveSelection(by: -100_000, extend: true)
                return true
            case 119:
                activeTab?.moveSelection(by: 100_000, extend: true)
                return true
            case 48:
                activateOtherPane()
                return true
            default:
                return false
            }
        }

        switch event.keyCode {
        case 36:
            renameSelection()
            return true
        case 49:
            toggleQuickLook()
            return true
        case 51, 117:
            trashSelection()
            return true
        case 48:
            activateOtherPane()
            return true
        case 125:
            moveSelection(delta: verticalStep)
            return true
        case 126:
            moveSelection(delta: -verticalStep)
            return true
        case 123:
            if activeTab?.viewMode == .columns {
                goUp()
            } else {
                activeTab?.moveSelection(by: -1)
            }
            return true
        case 124:
            if activeTab?.viewMode == .columns {
                activeTab?.drillSelected()
            } else {
                activeTab?.moveSelection(by: 1)
            }
            return true
        case 116:
            activeTab?.moveSelection(by: -10)
            return true
        case 121:
            activeTab?.moveSelection(by: 10)
            return true
        case 115:
            activeTab?.moveSelection(by: -100_000)
            return true
        case 119:
            activeTab?.moveSelection(by: 100_000)
            return true
        case 76:
            openSelection()
            return true
        case 53:
            if let tab = activeTab {
                if !tab.filter.isEmpty {
                    tab.filter = ""
                    return true
                }
                if tab.showsSearch {
                    tab.showsSearch = false
                    return true
                }
            }
            return false
        default:
            break
        }

        if let characters = event.characters,
           !characters.isEmpty,
           event.keyCode != 36, event.keyCode != 48, event.keyCode != 49 {
            let scalars = characters.unicodeScalars
            let isFunctionKey = scalars.contains {
                (0xF700...0xF8FF).contains(Int($0.value))
            }
            if !isFunctionKey && scalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }) {
                typeAheadBuffer += characters
                activeTab?.selectByPrefix(typeAheadBuffer)
                typeAheadResetWork?.cancel()
                let work = DispatchWorkItem { [weak self] in
                    self?.typeAheadBuffer = ""
                }
                typeAheadResetWork = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9, execute: work)
                return true
            }
        }
        return false
    }

    func openEnclosingInNewTab() {
        guard let tab = activeTab else { return }
        let parent = tab.currentFolder.deletingLastPathComponent()
        guard parent.path != tab.currentFolder.path else { return }
        newTab(at: parent)
    }

    private var verticalStep: Int {
        guard let tab = activeTab else { return 1 }
        switch tab.viewMode {
        case .icons:
            return max(1, tab.gridColumnCount)
        case .list, .columns:
            return 1
        }
    }

    private func moveSelection(delta: Int, extend: Bool = false) {
        activeTab?.moveSelection(by: delta, extend: extend)
    }

    // MARK: - Gesti di navigazione (trackpad e pulsanti del mouse)

    private func installNavigationGestures() {
        swipeMonitor = NSEvent.addLocalMonitorForEvents(matching: .swipe) { [weak self] event in
            guard let self, self.eventIsInMainWindow(event),
                  NSApp.keyWindow?.attachedSheet == nil,
                  !KeyMonitor.isEditingText else { return event }

            if event.deltaX > 0 {
                self.swipeBack()
                return nil
            }
            if event.deltaX < 0 {
                self.swipeForward()
                return nil
            }
            return event
        }

        extraButtonMonitor = NSEvent.addLocalMonitorForEvents(matching: .otherMouseDown) { [weak self] event in
            guard let self, self.eventIsInMainWindow(event),
                  NSApp.keyWindow?.attachedSheet == nil else { return event }

            switch event.buttonNumber {
            case 3:
                self.swipeBack()
                return nil
            case 4:
                self.swipeForward()
                return nil
            default:
                return event
            }
        }

        scrollSwipeMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            self?.handleScrollSwipe(event) ?? event
        }
    }

    // MARK: - Swipe orizzontale (fallback per trackpad)

    private func handleScrollSwipe(_ event: NSEvent) -> NSEvent? {
        guard let window = event.window,
              window === mainWindow,
              window.attachedSheet == nil,
              RunLoop.current.currentMode != .eventTracking,
              event.hasPreciseScrollingDeltas,
              let tab = activeTab,
              tab.viewMode != .columns,
              ClickRegistry.shared.areaTarget(at: event.locationInWindow, in: window) != nil else {
            resetScrollSwipe()
            return event
        }

        // Gli eventi di inerzia non devono far scattare la navigazione.
        if !event.momentumPhase.isEmpty {
            return swipeTriggered ? nil : event
        }

        let phase = event.phase

        if phase.contains(.began) || phase.contains(.mayBegin) {
            swipeAccumX = 0
            swipeAccumY = 0
            swipeTriggered = false
        }

        if phase.contains(.changed) {
            swipeAccumX += event.scrollingDeltaX
            swipeAccumY += event.scrollingDeltaY

            if !swipeTriggered,
               abs(swipeAccumX) > 120,
               abs(swipeAccumX) > abs(swipeAccumY) * 1.5 {
                swipeTriggered = true
                if swipeAccumX > 0 {
                    swipeBack()
                } else {
                    swipeForward()
                }
                return nil
            }

            if swipeTriggered { return nil }
        }

        if phase.contains(.ended) || phase.contains(.cancelled) {
            let triggered = swipeTriggered
            resetScrollSwipe()
            if triggered { return nil }
        }

        return event
    }

    private func resetScrollSwipe() {
        swipeAccumX = 0
        swipeAccumY = 0
        swipeTriggered = false
    }

    private func eventIsInMainWindow(_ event: NSEvent) -> Bool {
        guard let eventWindow = event.window, let mainWindow else { return false }
        return eventWindow === mainWindow
    }

    private var mainWindow: NSWindow? {
        NSApp.windows
            .filter { $0.isVisible && !($0 is NSPanel) }
            .max(by: {
                ($0.frame.width * $0.frame.height) < ($1.frame.width * $1.frame.height)
            })
    }

    // MARK: - Monitor dei click sulle righe

    private func installClickMonitor() {
        clickMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .leftMouseUp, .leftMouseDragged, .rightMouseDown, .otherMouseDown]
        ) { [weak self] event in
            guard let self else { return event }
            return self.handleClickEvent(event)
        }
    }

    private func handleClickEvent(_ event: NSEvent) -> NSEvent? {
        guard let window = event.window,
              window === mainWindow,
              window.attachedSheet == nil,
              RunLoop.current.currentMode != .eventTracking else {
            return event
        }

        if let hit = window.contentView?.hitTest(event.locationInWindow), hit is NSScroller {
            return event
        }

        switch event.type {
        case .leftMouseDown:
            guard let target = ClickRegistry.shared.target(for: event) else {
                pendingDrag = nil
                dragStarted = false

                if !event.modifierFlags.contains(.control),
                   event.clickCount == 1,
                   let area = ClickRegistry.shared.areaTarget(
                        at: event.locationInWindow,
                        in: window
                   ) {
                    area.performSingle(event)
                }
                return event
            }

            if event.modifierFlags.contains(.control) {
                pendingDrag = nil
                target.showContextMenu(event)
                return nil
            }

            if event.clickCount == 1 {
                target.performSingle(event)
                pendingDrag = (target, event, event.locationInWindow)
                dragStarted = false
            } else if event.clickCount == 2 {
                pendingDrag = nil
                dragStarted = false
                target.performDouble(event)
            }
            return event

        case .leftMouseDragged:
            guard let pending = pendingDrag, !dragStarted else { return event }
            let point = event.locationInWindow
            let distance = hypot(point.x - pending.point.x, point.y - pending.point.y)
            guard distance >= 4 else { return event }

            let urls = pending.target.dragURLs?() ?? []
            guard !urls.isEmpty else {
                pendingDrag = nil
                return event
            }

            dragStarted = true
            pendingDrag = nil
            pending.target.startDrag(with: pending.event, urls: urls)
            return nil

        case .leftMouseUp:
            pendingDrag = nil
            dragStarted = false
            return event

        case .rightMouseDown:
            guard let target = ClickRegistry.shared.target(for: event) else { return event }
            target.showContextMenu(event)
            return nil

        case .otherMouseDown:
            if event.buttonNumber == 2,
               let target = ClickRegistry.shared.target(for: event) {
                target.performMiddle(event)
                return nil
            }
            return event

        default:
            return event
        }
    }

    // MARK: - Hook di sviluppo

    private func applyDebugEnvironment() {
        let env = ProcessInfo.processInfo.environment

        if let mode = env["COMMANDER_VIEW_MODE"], let parsed = ViewMode(rawValue: mode) {
            defaultViewMode = parsed
        }
        if let size = env["COMMANDER_ICON_SIZE"], let parsed = Double(size) {
            zoom.iconSize = min(160, max(48, parsed))
        }
        if env["COMMANDER_PREVIEW"] == "0" {
            showPreview = false
        }
        if env["COMMANDER_SIDEBAR"] == "0" {
            showSidebar = false
        }

        if let path = env["COMMANDER_DRILL"] {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let tab = self?.activeTab,
                      let item = tab.visibleItems.first(where: { $0.name == path }) else { return }
                tab.click(item, columnIndex: tab.columns.count - 1, modifiers: [])
            }
        }

        if let path = env["COMMANDER_SELECT"] {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
                self?.activeTab?.selection = [url]
            }
        }

        if env["COMMANDER_SWITCH_VIEW"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in
                guard let self else { return }
                self.defaultViewMode = self.defaultViewMode == .icons ? .list : .icons
            }
        }

        if env["COMMANDER_CONNECT"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.beginConnectToServer()
            }
        }

        if let scheme = env["COMMANDER_CONNECT_FIRST"] {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) { [weak self] in
                guard let self else { return }
                if let server = self.network.servers.first(where: { $0.scheme == scheme }) {
                    self.connect(to: server)
                } else {
                    FileHandle.standardError.write(Data("CONNECT: no \(scheme) server\n".utf8))
                }
            }
        }

        if let volumeName = env["COMMANDER_EJECT"] {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                guard let self else { return }
                if let volume = self.volumes.first(where: { $0.name == volumeName }) {
                    print("EJECT: \(volume.name) at \(volume.url.path)")
                    self.eject(volume)
                } else {
                    print("EJECT: volume not found: \(volumeName)")
                }
            }
        }

        if env["COMMANDER_QUICKLOOK"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.toggleQuickLook()
            }
        }

        if env["COMMANDER_INFO"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                self?.getInfo()
            }
        }

        if env["COMMANDER_SETTINGS"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                self?.showSettings()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                for window in NSApp.windows {
                    let line = "WINDOW title=\(window.title) visible=\(window.isVisible) class=\(type(of: window)) id=\(window.identifier?.rawValue ?? "")\n"
                    FileHandle.standardError.write(Data(line.utf8))
                }
                for item in NSApp.mainMenu?.items.first?.submenu?.items ?? [] {
                    let line = "APPMENU \(item.title) action=\(String(describing: item.action)) target=\(String(describing: item.target))\n"
                    FileHandle.standardError.write(Data(line.utf8))
                }
            }
        }

        if env["COMMANDER_VIEW_OPTIONS"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                self?.showViewOptions = true
            }
        }

        if env["COMMANDER_SEARCH_SUBFOLDERS"] == "1" {
            searchSubfolders = true
        }

        if let filter = env["COMMANDER_FILTER"] {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in
                self?.activeTab?.filter = filter
            }
        }

        if let tagName = env["COMMANDER_TAG_SHOW"] {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self,
                      let tag = self.tagDefinitions.first(where: { $0.name == tagName }) else {
                    return
                }
                self.showTag(tag)
            }
        }

        if let path = env["COMMANDER_TAG_TEST"] {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
                self?.toggleTag("Red", on: [url])
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    let tags = self?.tags(of: url) ?? []
                    let line = "TAGTEST tags=\(tags)\n"
                    FileHandle.standardError.write(Data(line.utf8))
                }
            }
        }

        if let path = env["COMMANDER_ACTION_TEST"] {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
                self?.compress([url])
                self?.makeAlias([url])
            }
        }

        if env["COMMANDER_SIMULATE_DOUBLE"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
                guard let self, let window = self.mainWindow else { return }
                let targets = ClickRegistry.shared.targets(in: window)
                guard let target = targets.first else {
                    print("SIMULATE: no targets")
                    return
                }
                let rect = target.superview.map {
                    $0.convert(target.frame, to: nil)
                } ?? target.frame
                guard let event = NSEvent.mouseEvent(
                    with: .leftMouseDown,
                    location: NSPoint(x: rect.midX, y: rect.midY),
                    modifierFlags: [],
                    timestamp: ProcessInfo.processInfo.systemUptime,
                    windowNumber: window.windowNumber,
                    context: nil,
                    eventNumber: 0,
                    clickCount: 2,
                    pressure: 1
                ) else { return }

                print("SIMULATE double at", rect, "window:", event.window as Any)
                let result = self.handleClickEvent(event)
                print("SIMULATE consumed:", result == nil)
            }
        }

        if env["COMMANDER_SIMULATE_BACKGROUND"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
                guard let self, let window = self.mainWindow else { return }
                let areas = ClickRegistry.shared.areaTargets(in: window)
                guard let area = areas.first,
                      let superview = area.superview else {
                    print("SIMULATE BG: no areas")
                    return
                }
                let rect = superview.convert(area.frame, to: nil)
                let point = NSPoint(x: rect.midX, y: rect.minY + 20)
                guard let event = NSEvent.mouseEvent(
                    with: .leftMouseDown,
                    location: point,
                    modifierFlags: [],
                    timestamp: ProcessInfo.processInfo.systemUptime,
                    windowNumber: window.windowNumber,
                    context: nil,
                    eventNumber: 0,
                    clickCount: 1,
                    pressure: 1
                ) else { return }

                print("SIMULATE BG rect:", rect, "point:", point, "areas:", areas.count)
                let result = self.handleClickEvent(event)
                print("SIMULATE BG consumed:", result == nil)
            }
        }

        if env["COMMANDER_OPERATION_PANEL"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.fileOperations.showPreviewPanel()
            }
        }

        if env["COMMANDER_PRINT_SERVERS"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
                for server in self?.network.servers ?? [] {
                    let line = "SERVER name=\(server.name) host=\(server.host) connect=\(server.connectHost) scheme=\(server.scheme) valid=\(server.hasValidHost)\n"
                    FileHandle.standardError.write(Data(line.utf8))
                }
            }
        }

        if env["COMMANDER_PRINT_CONTEXT_MENU"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self, let tab = self.activeTab, let item = tab.visibleItems.first else {
                    FileHandle.standardError.write(Data("CONTEXT: no item\n".utf8))
                    return
                }
                for option in [false, true] {
                    let menu = FileMenuBuilder.menu(for: item, tab: tab, app: self, option: option)
                    let serviceTitles = NSApp.servicesMenu?.items.map(\.title) ?? []
                    let header = "CONTEXT option=\(option) item=\(item.name) services=\(serviceTitles)\n"
                    FileHandle.standardError.write(Data(header.utf8))
                    for entry in menu.items {
                        let sub = entry.submenu?.items.map(\.title).joined(separator: " | ") ?? ""
                        let line = "  \(entry.title) enabled=\(entry.isEnabled) sub=[\(sub)]\n"
                        FileHandle.standardError.write(Data(line.utf8))
                    }
                }
            }
        }
    }
}
