import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct IconGridView: View {
    @ObservedObject var tab: BrowserTab
    @ObservedObject var pane: PaneState
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var zoom: ZoomState

    @State private var dropTargeted = false
    @State private var zoomBase: Double?

    private var isActivePane: Bool { app.activePaneID == pane.id }

    var body: some View {
        GeometryReader { geometry in
            let cellWidth = max(zoom.iconSize + 44, 96)
            let count = max(1, Int((geometry.size.width - 32) / cellWidth))
            let columns = Array(
                repeating: GridItem(.fixed(cellWidth), spacing: 6, alignment: .top),
                count: count
            )

            ScrollViewReader { proxy in
                ScrollView {
                    if tab.visibleItems.isEmpty {
                        if tab.showsTrashPermissionHelp {
                            TrashPermissionView(tab: tab)
                        } else {
                            EmptyFolderView(
                                message: emptyMessage,
                                detail: emptyDetail
                            )
                            .frame(minHeight: max(200, geometry.size.height - 32))
                        }
                    } else {
                        LazyVGrid(columns: columns, alignment: .center, spacing: 14) {
                            ForEach(tab.visibleItems) { item in
                                InteractiveIconCell(
                                    item: item,
                                    tab: tab,
                                    pane: pane,
                                    size: zoom.iconSize,
                                    selected: tab.selection.contains(item.url),
                                    active: isActivePane
                                )
                                .id(item.url)
                            }
                        }
                        .padding(16)
                    }
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
            .onAppear {
                tab.gridColumnCount = count
            }
            .onChange(of: count) { _, value in
                tab.gridColumnCount = value
            }
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
        .simultaneousGesture(zoomGesture)
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

    private var zoomGesture: some Gesture {
        MagnifyGesture(minimumScaleDelta: 0.01)
            .onChanged { value in
                if zoomBase == nil { zoomBase = zoom.iconSize }
                let base = zoomBase ?? zoom.iconSize
                zoom.iconSize = min(160, max(48, base * value.magnification))
            }
            .onEnded { _ in
                zoomBase = nil
            }
    }
}

struct IconCell: View {
    let item: FileItem
    let size: Double
    let selected: Bool
    let active: Bool
    var hovered = false
    var showIconPreviews = true
    var showItemInfo = false

    var body: some View {
        VStack(spacing: 5) {
            ZStack(alignment: .bottomTrailing) {
                FileIconView(item: item, size: size, preferThumbnail: showIconPreviews)
                    .frame(width: size, height: size)

                if let color = item.tagColor {
                    Circle()
                        .fill(color)
                        .frame(width: 7, height: 7)
                        .overlay(Circle().stroke(Color(nsColor: .textBackgroundColor), lineWidth: 1))
                        .offset(x: 2, y: 2)
                }
            }
            .frame(width: size, height: size)

            Text(item.name)
                .font(.system(size: 12))
                .foregroundStyle(selected && active ? Palette.selectedText : Palette.text)
                .lineLimit(2)
                .truncationMode(.middle)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .frame(height: 30, alignment: .top)

            if showItemInfo {
                Text(item.isBrowsableFolder ? "—" : Format.bytes(item.size))
                    .font(.system(size: 10))
                    .foregroundStyle(selected && active ? Palette.selectedTextSecondary : Palette.textTertiary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .frame(height: 14, alignment: .top)
            }
        }
        .padding(.horizontal, 5)
        .padding(.top, 7)
        .padding(.bottom, 5)
        .frame(width: max(size + 44, 96))
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(backgroundColor)
        )
        .contentShape(Rectangle())
    }

    private var backgroundColor: Color {
        if selected {
            return active ? Palette.selection : Palette.selectionInactive
        }
        return hovered ? Color(nsColor: .quaternaryLabelColor).opacity(0.14) : .clear
    }
}

private struct InteractiveIconCell: View {
    let item: FileItem
    let tab: BrowserTab
    let pane: PaneState
    let size: Double
    let selected: Bool
    let active: Bool

    @EnvironmentObject private var app: AppState
    @State private var hovered = false

    var body: some View {
        ZStack {
            IconCell(
                item: item,
                size: size,
                selected: selected,
                active: active,
                hovered: hovered,
                showIconPreviews: app.showIconPreviews,
                showItemInfo: app.showIconItemInfo
            )
            ItemInteraction(
                item: item,
                tab: tab,
                pane: pane,
                mode: .icons
            )
        }
        .onHover { hovered = $0 }
    }
}
