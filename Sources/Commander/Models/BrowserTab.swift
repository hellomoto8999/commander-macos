import Foundation
import AppKit
import SwiftUI

/// Stato di una singola scheda: percorso, colonne Miller, selezione, cronologia.
final class BrowserTab: ObservableObject, Identifiable {
    let id = UUID()
    weak var app: AppState?

    @Published private(set) var basePath: URL
    @Published var columns: [URL] = []
    @Published var columnItems: [URL: [FileItem]] = [:]
    @Published var columnSelection: [URL: URL] = [:]
    @Published var selection: Set<URL> = []
    @Published var filter = "" {
        didSet {
            if oldValue != filter { scheduleSearch() }
        }
    }
    @Published var sortField: SortField = .name
    @Published var sortAscending = true
    @Published var isLoading = false
    @Published var errorText: String?
    @Published var history: [URL] = []
    @Published var historyIndex = -1
    @Published var showsSearch = false
    @Published var viewMode: ViewMode
    @Published var hoveredURL: URL?
    @Published private(set) var searchResults: [FileItem] = []
    @Published private(set) var isSearching = false
    @Published private(set) var tagFilterName: String?
    @Published private(set) var tagResults: [FileItem] = []
    @Published private(set) var isTagSearching = false
    var gridColumnCount = 1

    private var listAnchor: URL?
    private var generation = 0
    private var searchGeneration = 0
    private var searchWorkItem: DispatchWorkItem?
    private var tagSearchGeneration = 0

    init(path: URL, app: AppState?, viewMode: ViewMode) {
        self.basePath = path
        self.app = app
        self.viewMode = viewMode
        self.columns = [path]
        self.history = [path]
        self.historyIndex = 0
        load(path)
    }

    // MARK: - Percorsi

    var currentFolder: URL { columns.last ?? basePath }

    var title: String {
        if let tagFilterName { return tagFilterName }
        if isTrashFolder { return L("Trash") }
        let name = currentFolder.lastPathComponent
        return name.isEmpty ? "Macintosh HD" : name
    }

    var isTrashFolder: Bool {
        let trash = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".Trash")
            .standardizedFileURL
        return currentFolder.standardizedFileURL == trash
    }

    var showsTrashPermissionHelp: Bool {
        isTrashFolder && errorText != nil
    }

    var canGoBack: Bool { historyIndex > 0 }
    var canGoForward: Bool { historyIndex < history.count - 1 }

    // MARK: - Contenuti

    func items(in folder: URL) -> [FileItem] {
        let raw = columnItems[folder] ?? []
        let filtered: [FileItem]
        if folder == currentFolder, tagFilterName != nil {
            filtered = filter.isEmpty
                ? tagResults
                : tagResults.filter { $0.name.localizedCaseInsensitiveContains(filter) }
        } else if folder == currentFolder && !filter.isEmpty {
            if app?.searchSubfolders == true {
                filtered = searchResults
            } else {
                filtered = raw.filter { $0.name.localizedCaseInsensitiveContains(filter) }
            }
        } else {
            filtered = raw
        }
        return FileSystem.sorted(
            filtered,
            by: sortField,
            ascending: sortAscending,
            foldersFirst: app?.foldersFirst ?? true
        )
    }

    var visibleItems: [FileItem] { items(in: currentFolder) }

    var selectedItems: [FileItem] {
        var lookup: [URL: FileItem] = [:]
        for list in columnItems.values {
            for item in list { lookup[item.url] = item }
        }
        return selection.compactMap { lookup[$0] }
    }

    var selectedSize: Int64 {
        selectedItems.reduce(0) { $0 + $1.size }
    }

    var previewURL: URL? {
        if !selection.isEmpty { return selection.first }
        return columnSelection[currentFolder]
    }

    var previewItems: [URL] {
        if !selection.isEmpty { return Array(selection) }
        return [currentFolder]
    }

    // MARK: - Caricamento

    func load(_ folder: URL, force: Bool = false) {
        if !force, columnItems[folder] != nil { return }
        generation += 1
        let hidden = app?.showHidden ?? false
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Result { try FileSystem.list(folder, showHidden: hidden) }
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let items):
                    self.columnItems[folder] = items
                    self.errorText = nil
                case .failure(let error):
                    self.errorText = error.localizedDescription
                }
                self.isLoading = false
            }
        }
    }

    func refresh() {
        let folders = columns
        for folder in folders {
            load(folder, force: true)
        }
        scheduleSearch()
    }

    func applyTagFilter(_ name: String) {
        tagFilterName = name
        filter = ""
        tagSearchGeneration += 1
        let generation = tagSearchGeneration
        isTagSearching = true
        tagResults = []

        let home = FileManager.default.homeDirectoryForCurrentUser
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let results = FileSystem.searchByTag(name, in: home, limit: 2_000)
            DispatchQueue.main.async {
                guard let self, self.tagSearchGeneration == generation else { return }
                self.tagResults = results
                self.isTagSearching = false
            }
        }
    }

    func clearTagFilter() {
        guard tagFilterName != nil || !tagResults.isEmpty else { return }
        tagSearchGeneration += 1
        tagFilterName = nil
        tagResults = []
        isTagSearching = false
    }

    func scheduleSearch() {
        searchWorkItem?.cancel()
        searchGeneration += 1
        let generation = searchGeneration

        guard !filter.isEmpty, app?.searchSubfolders == true else {
            isSearching = false
            searchResults = []
            return
        }

        let folder = currentFolder
        let query = filter
        let showHidden = app?.showHidden ?? false
        isSearching = true

        let work = DispatchWorkItem { [weak self] in
            let results = FileSystem.search(
                in: folder,
                query: query,
                showHidden: showHidden,
                limit: 2_000
            )
            DispatchQueue.main.async {
                guard let self, self.searchGeneration == generation else { return }
                self.searchResults = results
                self.isSearching = false
            }
        }
        searchWorkItem = work
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.2, execute: work)
    }

    func reloadCurrent() {
        load(currentFolder, force: true)
    }

    // MARK: - Navigazione

    func navigate(to url: URL, addHistory: Bool = true) {
        let target = url.standardizedFileURL
        basePath = target
        columns = [target]
        columnSelection.removeAll()
        selection = []
        listAnchor = nil
        filter = ""
        clearTagFilter()
        if addHistory {
            if historyIndex < history.count - 1 {
                history = Array(history.prefix(historyIndex + 1))
            }
            if history.last != target {
                history.append(target)
                historyIndex = history.count - 1
            }
        }
        load(target, force: true)
        app?.schedulePersist()
    }

    func goBack() {
        guard canGoBack else { return }
        historyIndex -= 1
        navigate(to: history[historyIndex], addHistory: false)
    }

    func goForward() {
        guard canGoForward else { return }
        historyIndex += 1
        navigate(to: history[historyIndex], addHistory: false)
    }

    func goUp() {
        if columns.count > 1 {
            let closing = columns.removeLast()
            if let parent = columns.last {
                columnSelection[parent] = closing
                selection = [closing]
            }
        } else if basePath.path != "/" {
            navigate(to: basePath.deletingLastPathComponent())
        }
        app?.schedulePersist()
    }

    // MARK: - Interazione

    func click(_ item: FileItem, columnIndex: Int, modifiers: NSEvent.ModifierFlags) {
        guard columnIndex < columns.count else { return }
        let folder = columns[columnIndex]

        if modifiers.contains(.command) {
            columns = Array(columns.prefix(columnIndex + 1))
            columnSelection[folder] = item.url
            if selection.contains(item.url) {
                selection.remove(item.url)
            } else {
                selection.insert(item.url)
            }
            listAnchor = item.url
            return
        }

        if modifiers.contains(.shift) {
            columns = Array(columns.prefix(columnIndex + 1))
            selectRange(to: item, in: folder)
            return
        }

        columnSelection[folder] = item.url
        columns = Array(columns.prefix(columnIndex + 1))
        selection = [item.url]
        listAnchor = item.url

        if item.isBrowsableFolder {
            columns.append(item.url)
            columnSelection.removeValue(forKey: item.url)
            load(item.url)
        }
        app?.schedulePersist()
    }

    func clickList(_ item: FileItem, modifiers: NSEvent.ModifierFlags) {
        if modifiers.contains(.command) {
            if selection.contains(item.url) {
                selection.remove(item.url)
            } else {
                selection.insert(item.url)
            }
            listAnchor = item.url
        } else if modifiers.contains(.shift) {
            selectRange(to: item, in: currentFolder)
        } else {
            selection = [item.url]
            listAnchor = item.url
        }
    }

    private func selectRange(to item: FileItem, in folder: URL) {
        let list = items(in: folder)
        let anchor = listAnchor ?? item.url
        guard let start = list.firstIndex(where: { $0.url == anchor }),
              let end = list.firstIndex(where: { $0.url == item.url }) else {
            selection = [item.url]
            return
        }
        let range = start <= end ? start...end : end...start
        selection = Set(list[range].map(\.url))
    }

    func selectByPrefix(_ prefix: String) {
        let items = visibleItems
        guard !items.isEmpty, !prefix.isEmpty else { return }
        let needle = prefix.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let start = selection.first
            .flatMap { current in items.firstIndex(where: { $0.url == current }) } ?? 0
        let ordered = Array(items[start...]) + Array(items[..<start])
        guard let match = ordered.first(where: {
            $0.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .hasPrefix(needle)
        }) else { return }
        selection = [match.url]
        listAnchor = match.url
        columnSelection[currentFolder] = match.url
    }

    func open(_ item: FileItem) {
        if item.isBrowsableFolder {
            if app?.openFoldersInNewTab == true {
                app?.newTab(at: item.url)
            } else {
                navigate(to: item.url)
            }
        } else {
            NSWorkspace.shared.open(item.url)
        }
    }

    func openSelection() {
        let items = selectedItems
        guard !items.isEmpty else { return }
        if items.count == 1 {
            open(items[0])
        } else {
            for item in items where !item.isBrowsableFolder {
                NSWorkspace.shared.open(item.url)
            }
        }
    }

    func selectAll() {
        selection = Set(visibleItems.map(\.url))
        listAnchor = visibleItems.first?.url
    }

    func moveSelection(by delta: Int, extend: Bool = false) {
        let list = visibleItems
        guard !list.isEmpty else { return }
        let current = list.firstIndex(where: { selection.contains($0.url) })
        let base = current ?? (delta > 0 ? -1 : list.count)
        let target = min(max(0, base + delta), list.count - 1)
        let item = list[target]

        if extend, let anchorURL = listAnchor,
           let anchor = list.firstIndex(where: { $0.url == anchorURL }) {
            let range = anchor <= target ? anchor...target : target...anchor
            selection = Set(list[range].map(\.url))
        } else {
            selection = [item.url]
            listAnchor = item.url
        }
        columnSelection[currentFolder] = item.url
    }

    func drillSelected() {
        guard let url = selection.first,
              let item = visibleItems.first(where: { $0.url == url }),
              item.isBrowsableFolder else { return }
        click(item, columnIndex: columns.count - 1, modifiers: [])
    }

    func clearSelection() {
        selection.removeAll()
        columnSelection.removeValue(forKey: currentFolder)
        listAnchor = nil
    }

    func contextSelect(_ item: FileItem, in folder: URL?) {
        if !selection.contains(item.url) {
            selection = [item.url]
        }
        if let folder {
            columnSelection[folder] = item.url
        }
        listAnchor = item.url
    }

    func renameTarget() -> FileItem? {
        guard selection.count == 1, let url = selection.first else { return nil }
        return selectedItems.first ?? FileItem(url: url)
    }

    func sort(by field: SortField) {
        if sortField == field {
            sortAscending.toggle()
        } else {
            sortField = field
            sortAscending = true
        }
    }

    // MARK: - Permanenza

    var persistedPath: String { currentFolder.path }
}
