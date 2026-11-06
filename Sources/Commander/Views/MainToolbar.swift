import SwiftUI
import AppKit

// MARK: - Toolbar principale

struct MainToolbar: ToolbarContent {
    @ObservedObject var app: AppState

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            if let tab = app.activeTab {
                ToolbarNavigation(tab: tab)
            }
        }

        ToolbarItem(placement: .navigation) {
            if let tab = app.activeTab {
                ToolbarNewMenu(tab: tab)
            }
        }

        ToolbarItem(placement: .principal) {
            if let tab = app.activeTab {
                ToolbarTitle(tab: tab)
            }
        }

        ToolbarItemGroup(placement: .primaryAction) {
            if let tab = app.activeTab {
                ToolbarViewControls(tab: tab)
            }
        }

        ToolbarItem(placement: .primaryAction) {
            if let tab = app.activeTab {
                ToolbarSearch(tab: tab)
            }
        }

        ToolbarItemGroup(placement: .primaryAction) {
            ToolbarToggles()
        }
    }
}

// MARK: - Nuovo

struct ToolbarNewMenu: View {
    @ObservedObject var tab: BrowserTab
    @EnvironmentObject private var app: AppState

    var body: some View {
        Menu {
            Button(L("New Tab")) { app.newTab() }
            Button(L("New Folder")) { app.createFolder(in: tab.currentFolder) }
            Button(L("New File")) { app.createFile(in: tab.currentFolder) }
            Divider()
            Button(L("Add to Favorites")) { app.addFavorite(tab.currentFolder) }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 15, weight: .semibold))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(L("New"))
    }
}

// MARK: - Navigazione

struct ToolbarTitle: View {
    @ObservedObject var tab: BrowserTab

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "folder")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Text(tab.title)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(maxWidth: 280)
        .help(tab.currentFolder.path)
    }
}

struct ToolbarNavigation: View {
    @ObservedObject var tab: BrowserTab

    var body: some View {
        Button {
            tab.goBack()
        } label: {
            Image(systemName: "chevron.backward")
                .font(.system(size: 15, weight: .medium))
        }
        .help(L("Back"))
        .disabled(!tab.canGoBack)

        Button {
            tab.goForward()
        } label: {
            Image(systemName: "chevron.forward")
                .font(.system(size: 15, weight: .medium))
        }
        .help(L("Forward"))
        .disabled(!tab.canGoForward)

        Button {
            tab.goUp()
        } label: {
            Image(systemName: "arrow.up")
                .font(.system(size: 15, weight: .medium))
        }
        .help(L("Enclosing Folder"))
        .disabled(tab.columns.count <= 1 && tab.currentFolder.path == "/")
    }
}

// MARK: - Vista, ordinamento, condivisione, azioni

struct ToolbarViewControls: View {
    @ObservedObject var tab: BrowserTab
    @EnvironmentObject private var app: AppState

    var body: some View {
        Picker(L("View"), selection: Binding(
            get: { tab.viewMode },
            set: { app.setViewMode($0) }
        )) {
            ForEach(ViewMode.allCases) { mode in
                Image(systemName: mode.symbol)
                    .help(mode.label)
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .controlSize(.large)
        .frame(width: 126)
        .help(L("View"))

        Menu {
            ForEach(SortField.allCases) { field in
                Button {
                    tab.sort(by: field)
                } label: {
                    Label(field.label, systemImage: tab.sortField == field ? "checkmark" : field.symbol)
                }
            }
            Divider()
            Button {
                tab.sortAscending.toggle()
            } label: {
                Label(
                    tab.sortAscending ? L("Descending") : L("Ascending"),
                    systemImage: tab.sortAscending ? "arrow.down" : "arrow.up"
                )
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.arrow.down")
                Text(tab.sortField.label)
                    .font(.system(size: 12))
                Image(systemName: "chevron.down")
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .menuStyle(.borderlessButton)
        .controlSize(.large)
        .fixedSize()
        .help(L("Sort By"))

        Button {
            app.shareSelection()
        } label: {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 15))
        }
        .controlSize(.large)
        .help(L("Share…"))

        Menu {
            ToolbarActionItems(tab: tab)
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 16))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .controlSize(.large)
        .fixedSize()
        .help(L("Actions"))
    }
}

struct ToolbarActionItems: View {
    @ObservedObject var tab: BrowserTab
    @EnvironmentObject private var app: AppState

    var body: some View {
        Button(L("New Folder")) { app.createFolder(in: tab.currentFolder) }
        Button(L("New File")) { app.createFile(in: tab.currentFolder) }
        Divider()

        Button(L("Open")) { tab.openSelection() }
            .disabled(tab.selection.isEmpty)
        Button(L("Open in New Tab")) {
            if let url = tab.selection.first, FileItem(url: url).isBrowsableFolder {
                app.newTab(at: url)
            }
        }
        .disabled(!(tab.selection.first.map { FileItem(url: $0).isBrowsableFolder } ?? false))

        Divider()

        Button(L("Cut")) {
            FileClipboard.write(Array(tab.selection), cut: true)
        }
        .disabled(tab.selection.isEmpty)
        Button(L("Copy")) {
            FileClipboard.write(Array(tab.selection), cut: false)
        }
        .disabled(tab.selection.isEmpty)
        Button(L("Paste")) { app.paste(into: tab.currentFolder) }
            .disabled(!FileClipboard.hasFiles())
        Button(L("Duplicate")) { app.duplicate(Array(tab.selection)) }
            .disabled(tab.selection.isEmpty)
        Button(L("Rename")) { app.renameSelection() }
            .disabled(tab.selection.count != 1)
        Button(L("Move to Trash")) { app.trash(Array(tab.selection)) }
            .disabled(tab.selection.isEmpty)

        Divider()

        Button(L("Get Info")) { app.getInfo() }
        Button(L("Quick Look")) { QuickLookController.shared.toggle(urls: tab.previewItems) }
        Button(L("Share…")) { app.shareSelection() }
        Button(L("Copy Path")) { app.copyPath(tab.selection.first ?? tab.currentFolder) }
        Button(L("Show in Finder")) {
            let urls = tab.selection.isEmpty ? [tab.currentFolder] : Array(tab.selection)
            NSWorkspace.shared.activateFileViewerSelecting(urls)
        }
        Button(L("Open in Terminal")) { app.openTerminal(at: tab.currentFolder) }
        Button(L("Add to Favorites")) { app.addFavorite(tab.currentFolder) }

        Divider()

        Button(L("Select All")) { tab.selectAll() }
        Button(L("Refresh")) { tab.refresh() }
    }
}

// MARK: - Ricerca

struct ToolbarSearch: View {
    @ObservedObject var tab: BrowserTab
    @EnvironmentObject private var app: AppState
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            TextField(L("Filter"), text: $tab.filter)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .frame(width: 160)
                .focused($focused)
                .onExitCommand {
                    tab.filter = ""
                    focused = false
                }

            if !tab.filter.isEmpty {
                Button {
                    tab.filter = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 28)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Palette.border, lineWidth: 1)
        )
        .onChange(of: app.focusSearchToken) { _, _ in
            focused = true
        }
    }
}

// MARK: - Interruttori pannelli

struct ToolbarToggles: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.16)) { app.showSidebar.toggle() }
        } label: {
            Image(systemName: "sidebar.left")
                .font(.system(size: 15))
                .foregroundStyle(app.showSidebar ? Color.accentColor : Color.secondary)
        }
        .help(app.showSidebar ? L("Hide Sidebar") : L("Show Sidebar"))

        Button {
            withAnimation(.easeInOut(duration: 0.16)) { app.showPreview.toggle() }
        } label: {
            Image(systemName: "sidebar.right")
                .font(.system(size: 15))
                .foregroundStyle(app.showPreview ? Color.accentColor : Color.secondary)
        }
        .help(app.showPreview ? L("Hide Preview") : L("Show Preview"))

        Button {
            withAnimation(.easeInOut(duration: 0.16)) { app.dualPane.toggle() }
        } label: {
            Image(systemName: app.dualPane ? "rectangle.split.2x1.fill" : "rectangle")
                .font(.system(size: 15))
                .foregroundStyle(app.dualPane ? Color.accentColor : Color.secondary)
        }
        .help(app.dualPane ? L("Single Pane") : L("Double Pane"))
    }
}
