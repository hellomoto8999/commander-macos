import Foundation
import AppKit

/// Un pannello (sinistra/destra) con le sue schede.
final class PaneState: ObservableObject, Identifiable {
    let id = UUID()
    weak var app: AppState?

    @Published var tabs: [BrowserTab] = [] {
        didSet { app?.objectWillChange.send() }
    }
    @Published var selectedTabID: UUID? {
        didSet { app?.objectWillChange.send() }
    }

    var activeTab: BrowserTab? {
        if let selectedTabID, let tab = tabs.first(where: { $0.id == selectedTabID }) {
            return tab
        }
        return tabs.first
    }

    var activeIndex: Int? {
        guard let activeTab else { return nil }
        return tabs.firstIndex(where: { $0.id == activeTab.id })
    }

    init() {}

    func configure(app: AppState, paths: [URL], selected: Int) {
        self.app = app
        tabs = []
        let valid = paths.filter { FileSystem.fm.fileExists(atPath: $0.path) }
        let initial = valid.isEmpty ? [FileManager.default.homeDirectoryForCurrentUser] : valid
        for path in initial {
            tabs.append(BrowserTab(path: path, app: app, viewMode: app.defaultViewMode))
        }
        let index = min(max(0, selected), tabs.count - 1)
        selectedTabID = tabs[index].id
    }

    func activateTab(_ tab: BrowserTab) {
        selectedTabID = tab.id
    }

    @discardableResult
    func newTab(at url: URL? = nil, select: Bool = true) -> BrowserTab? {
        guard let app else { return nil }
        let target = url ?? activeTab?.currentFolder ?? FileManager.default.homeDirectoryForCurrentUser
        let tab = BrowserTab(
            path: target,
            app: app,
            viewMode: activeTab?.viewMode ?? app.defaultViewMode
        )
        tabs.append(tab)
        if select {
            selectedTabID = tab.id
        }
        app.schedulePersist()
        return tab
    }

    func closeTab(_ tab: BrowserTab) {
        guard tabs.count > 1, let index = tabs.firstIndex(where: { $0.id == tab.id }) else { return }
        let wasActive = (selectedTabID == tab.id)
        tabs.remove(at: index)
        if wasActive {
            let newIndex = min(index, tabs.count - 1)
            selectedTabID = tabs[newIndex].id
        }
        app?.schedulePersist()
    }

    func closeActiveTab() {
        guard let activeTab else { return }
        closeTab(activeTab)
    }

    func nextTab() {
        guard tabs.count > 1, let index = activeIndex else { return }
        selectedTabID = tabs[(index + 1) % tabs.count].id
        app?.schedulePersist()
    }

    func previousTab() {
        guard tabs.count > 1, let index = activeIndex else { return }
        selectedTabID = tabs[(index - 1 + tabs.count) % tabs.count].id
        app?.schedulePersist()
    }
}
