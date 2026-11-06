import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct MillerView: View {
    @ObservedObject var tab: BrowserTab
    @ObservedObject var pane: PaneState
    @EnvironmentObject private var app: AppState

    var body: some View {
        GeometryReader { geometry in
            let count = tab.columns.count
            let columnWidth: CGFloat = count <= 1
                ? min(300, max(240, geometry.size.width - 1))
                : max(190, min(300, (geometry.size.width - 2) / 2))

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: true) {
                    HStack(spacing: 0) {
                        ForEach(Array(tab.columns.enumerated()), id: \.offset) { index, folder in
                            MillerColumn(
                                tab: tab,
                                pane: pane,
                                folder: folder,
                                index: index
                            )
                            .frame(width: columnWidth)
                            .frame(maxHeight: .infinity)
                            .id("col:" + folder.path)

                            Rectangle()
                                .fill(Palette.border)
                                .frame(width: 1)
                        }
                    }
                    .frame(maxHeight: .infinity)
                }
                .background(Palette.panel)
                .onChange(of: tab.columns) { _, columns in
                    guard let last = columns.last else { return }
                    DispatchQueue.main.async {
                        withAnimation(.easeOut(duration: 0.18)) {
                            proxy.scrollTo("col:" + last.path, anchor: .trailing)
                        }
                    }
                }
            }
        }
    }
}

struct MillerColumn: View {
    @ObservedObject var tab: BrowserTab
    @ObservedObject var pane: PaneState
    @EnvironmentObject private var app: AppState

    let folder: URL
    let index: Int

    @State private var dropTargeted = false

    private var items: [FileItem] { tab.items(in: folder) }
    private var isActivePane: Bool { app.activePaneID == pane.id }

    var body: some View {
        VStack(spacing: 0) {
            if items.isEmpty {
                emptyState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(items) { item in
                                row(item)
                                    .id(item.url)
                            }
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 4)
                    }
                    .onChange(of: tab.columnSelection[folder]) { _, selected in
                        guard let selected else { return }
                        withAnimation(.easeOut(duration: 0.12)) {
                            proxy.scrollTo(selected, anchor: .center)
                        }
                    }
                    .onChange(of: tab.selection) { _, selection in
                        guard folder == tab.currentFolder, let first = selection.first else { return }
                        withAnimation(.easeOut(duration: 0.12)) {
                            proxy.scrollTo(first, anchor: .center)
                        }
                    }
                }
            }
        }
        .background(dropTargeted ? Color.accentColor.opacity(0.06) : Palette.column)
        .background(
            AreaTarget { _ in
                app.activate(pane)
                pane.activateTab(tab)
                tab.clearSelection()
            }
        )
        .overlay(
            Rectangle()
                .strokeBorder(Color.accentColor.opacity(dropTargeted ? 0.45 : 0), lineWidth: 1)
        )
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $dropTargeted) { providers in
            let copy = NSEvent.modifierFlags.contains(.option)
            DropHelper.urls(from: providers) { urls in
                guard !urls.isEmpty else { return }
                app.moveOrCopy(urls, to: folder, copy: copy)
            }
            return true
        }
        .contextMenu {
            FolderBackgroundMenu(tab: tab, folder: folder)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if tab.showsTrashPermissionHelp {
            TrashPermissionView(tab: tab)
        } else if tab.isLoading {
            ProgressView()
                .controlSize(.small)
        } else if let error = tab.errorText {
            Text(error)
                .font(.system(size: 11))
                .foregroundStyle(Palette.textTertiary)
                .multilineTextAlignment(.center)
                .padding(12)
        } else if !tab.filter.isEmpty {
            Text(L("No Results"))
                .font(.system(size: 11))
                .foregroundStyle(Palette.textTertiary)
        }
    }

    @ViewBuilder
    private func row(_ item: FileItem) -> some View {
        let selected = tab.columnSelection[folder] == item.url || tab.selection.contains(item.url)

        InteractiveColumnRow(
            item: item,
            tab: tab,
            pane: pane,
            folder: folder,
            index: index,
            selected: selected,
            active: isActivePane
        )
    }
}

struct ColumnFileRow: View {
    let item: FileItem
    let selected: Bool
    let active: Bool
    var hovered = false
    var body: some View {
        HStack(spacing: 6) {
            FileIconView(item: item, size: 16)

            Text(item.name)
                .font(.system(size: 13))
                .foregroundStyle(selected && active ? Palette.selectedText : Palette.text)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 4)

            if item.isBrowsableFolder {
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(selected && active ? Palette.selectedTextSecondary : Palette.textTertiary)
            }
        }
        .padding(.horizontal, 7)
        .frame(height: 24)
        .background(backgroundColor)
        .contentShape(Rectangle())
    }

    private var backgroundColor: Color {
        if selected {
            return active ? Palette.selection : Palette.selectionInactive
        }
        return hovered ? Palette.rowHover : Color.clear
    }
}

private struct InteractiveColumnRow: View {
    let item: FileItem
    let tab: BrowserTab
    let pane: PaneState
    let folder: URL
    let index: Int
    let selected: Bool
    let active: Bool

    @State private var hovered = false

    var body: some View {
        ZStack {
            ColumnFileRow(
                item: item,
                selected: selected,
                active: active,
                hovered: hovered
            )

            ItemInteraction(
                item: item,
                tab: tab,
                pane: pane,
                mode: .column(folder: folder, index: index)
            )
        }
        .onHover { hovered = $0 }
    }
}
