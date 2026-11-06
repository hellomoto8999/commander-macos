import SwiftUI
import AppKit

enum ItemClickMode {
    case list
    case icons
    case column(folder: URL, index: Int)
}

/// Collega una riga al monitor degli eventi: click, doppio click, tasto
/// destro, control-click, tasto centrale, ⌘/⇧ click, ⌘/⌥ doppio click,
/// selezione contestuale e drag.
struct ItemInteraction: View {
    let item: FileItem
    @ObservedObject var tab: BrowserTab
    @ObservedObject var pane: PaneState
    let mode: ItemClickMode

    @EnvironmentObject private var app: AppState

    var body: some View {
        RowTarget(
            onSingle: handleSingleClick,
            onDouble: handleDoubleClick,
            onMiddle: { _ in handleMiddleClick() },
            contextMenu: handleContextMenu,
            dragURLs: { dragURLs },
            dragImage: { IconProvider.shared.icon(for: item) }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Azioni

    private func activate() {
        app.activate(pane)
        pane.activateTab(tab)
    }

    private func handleSingleClick(_ event: NSEvent) {
        activate()

        if item.isBrowsableFolder,
           event.modifierFlags.contains(.option),
           case .column = mode {
            tab.selection = [item.url]
            return
        }

        switch mode {
        case .list, .icons:
            tab.clickList(item, modifiers: event.modifierFlags)
        case .column(_, let index):
            tab.click(item, columnIndex: index, modifiers: event.modifierFlags)
        }
    }

    private func handleDoubleClick(_ event: NSEvent) {
        activate()
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        if item.isBrowsableFolder {
            if flags.contains(.command) {
                app.newTab(at: item.url)
                return
            }
            if flags.contains(.option) {
                app.openInOtherPane(item.url)
                return
            }
            if case .column = mode {
                return
            }
        }

        tab.open(item)
    }

    private func handleMiddleClick() {
        activate()
        if item.isBrowsableFolder {
            app.newTab(at: item.url)
        } else {
            NSWorkspace.shared.open(item.url)
        }
    }

    private func handleContextMenu(_ event: NSEvent) -> NSMenu? {
        activate()
        let folder: URL?
        if case .column(let parent, _) = mode {
            folder = parent
        } else {
            folder = nil
        }
        tab.contextSelect(item, in: folder)
        return FileMenuBuilder.menu(
            for: item,
            tab: tab,
            app: app,
            option: event.modifierFlags.contains(.option)
        )
    }

    private var dragURLs: [URL] {
        if tab.selection.contains(item.url), tab.selection.count > 1 {
            return FileSystem.existingItems(at: Array(tab.selection))
        }
        return [item.url]
    }
}
