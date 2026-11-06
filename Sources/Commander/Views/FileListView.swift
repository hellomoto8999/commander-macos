import SwiftUI
import AppKit
import UniformTypeIdentifiers

private enum ListMetrics {
    static let date: CGFloat = 110
    static let size: CGFloat = 72
    static let kind: CGFloat = 140
    static let padding: CGFloat = 10
    static let gap: CGFloat = 6
}

struct FileListView: View {
    @ObservedObject var tab: BrowserTab
    @ObservedObject var pane: PaneState
    @EnvironmentObject private var app: AppState

    @State private var dropTargeted = false

    private var isActivePane: Bool { app.activePaneID == pane.id }

    var body: some View {
        GeometryReader { geometry in
            content(width: geometry.size.width)
        }
        .background(dropTargeted ? Color.accentColor.opacity(0.06) : Palette.panel)
        .overlay(
            Rectangle()
                .strokeBorder(Color.accentColor.opacity(dropTargeted ? 0.5 : 0), lineWidth: 1.5)
        )
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $dropTargeted) { providers in
            let copy = NSEvent.modifierFlags.contains(.option)
            DropHelper.urls(from: providers) { urls in
                guard !urls.isEmpty else { return }
                app.moveOrCopy(urls, to: tab.currentFolder, copy: copy)
            }
            return true
        }
    }

    private func content(width: CGFloat) -> some View {
        let showKind = width >= 560
        let showDate = width >= 360
        let showSize = width >= 320

        return VStack(spacing: 0) {
            header(showDate: showDate, showSize: showSize, showKind: showKind)
            Rectangle()
                .fill(Palette.border)
                .frame(height: 1)

            if tab.isLoading && tab.visibleItems.isEmpty {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if tab.visibleItems.isEmpty {
                if tab.showsTrashPermissionHelp {
                    TrashPermissionView(tab: tab)
                } else {
                    EmptyFolderView(message: emptyMessage, detail: emptyDetail)
                        .background(
                            AreaTarget { _ in
                                app.activate(pane)
                                pane.activateTab(tab)
                                tab.clearSelection()
                            }
                        )
                        .contextMenu {
                            FolderBackgroundMenu(tab: tab, folder: tab.currentFolder)
                        }
                }
            } else {
                rows(showDate: showDate, showSize: showSize, showKind: showKind)
            }
        }
    }

    private var emptyMessage: String {
        if tab.errorText != nil { return L("Cannot Read Folder") }
        if tab.isLoading { return L("Loading…") }
        if tab.isSearching || tab.isTagSearching { return L("Searching…") }
        if !tab.filter.isEmpty || tab.tagFilterName != nil { return L("No Results") }
        return L("Empty Folder")
    }

    private var emptyDetail: String? {
        if let error = tab.errorText { return error }
        if tab.isSearching || tab.isTagSearching { return nil }
        if tab.tagFilterName != nil { return nil }
        if !tab.filter.isEmpty && !tab.isLoading {
            return "\(L("No item matches")) “\(tab.filter)”."
        }
        return nil
    }

    private func header(showDate: Bool, showSize: Bool, showKind: Bool) -> some View {
        HStack(spacing: ListMetrics.gap) {
            sortHeader(L("Name"), field: .name)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

            if showDate {
                sortHeader(L("Date Modified"), field: .dateModified)
                    .frame(width: ListMetrics.date, alignment: .leading)
            }

            if showSize {
                sortHeader(L("Size"), field: .size, alignment: .trailing)
                    .frame(width: ListMetrics.size, alignment: .trailing)
            }

            if showKind {
                sortHeader(L("Kind"), field: .kind)
                    .frame(width: ListMetrics.kind, alignment: .leading)
            }
        }
        .padding(.horizontal, ListMetrics.padding)
        .frame(height: 24)
        .background(VisualEffectBackground(material: .headerView))
    }

    private func sortHeader(
        _ title: String,
        field: SortField,
        alignment: HorizontalAlignment = .leading
    ) -> some View {
        Button {
            tab.sort(by: field)
        } label: {
            HStack(spacing: 3) {
                if alignment == .leading {
                    Text(title)
                    sortArrow(field)
                    Spacer(minLength: 0)
                } else {
                    Spacer(minLength: 0)
                    Text(title)
                    sortArrow(field)
                }
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(tab.sortField == field ? Palette.text : Palette.textSecondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("\(L("Sort By")) \(title)")
    }

    @ViewBuilder
    private func sortArrow(_ field: SortField) -> some View {
        if tab.sortField == field {
            Image(systemName: tab.sortAscending ? "chevron.up" : "chevron.down")
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(Palette.textSecondary)
        }
    }

    private func rows(showDate: Bool, showSize: Bool, showKind: Bool) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(tab.visibleItems.enumerated()), id: \.element.id) { index, item in
                        InteractiveFileRow(
                            item: item,
                            tab: tab,
                            pane: pane,
                            isSelected: tab.selection.contains(item.url),
                            isActivePane: isActivePane,
                            alternate: index % 2 == 1,
                            showDate: showDate,
                            showSize: showSize,
                            showKind: showKind,
                            height: 24
                        )
                        .id(item.url)
                    }
                }
                .padding(.vertical, 1)
            }
            .onChange(of: tab.selection) { _, selection in
                guard let first = selection.first else { return }
                withAnimation(.easeOut(duration: 0.12)) {
                    proxy.scrollTo(first, anchor: .center)
                }
            }
            .background(
                AreaTarget { _ in
                    app.activate(pane)
                    pane.activateTab(tab)
                    tab.clearSelection()
                }
            )
            .contextMenu {
                FolderBackgroundMenu(tab: tab, folder: tab.currentFolder)
            }
        }
    }
}

private struct InteractiveFileRow: View {
    let item: FileItem
    let tab: BrowserTab
    let pane: PaneState
    let isSelected: Bool
    let isActivePane: Bool
    let alternate: Bool
    let showDate: Bool
    let showSize: Bool
    let showKind: Bool
    let height: CGFloat

    @State private var hovered = false

    var body: some View {
        ZStack {
            FileRow(
                item: item,
                isSelected: isSelected,
                isActivePane: isActivePane,
                alternate: alternate,
                hovered: hovered,
                showDate: showDate,
                showSize: showSize,
                showKind: showKind,
                height: height
            )

            ItemInteraction(
                item: item,
                tab: tab,
                pane: pane,
                mode: .list
            )
        }
        .onHover { hovered = $0 }
    }
}
