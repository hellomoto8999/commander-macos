import SwiftUI

struct PaneView: View {
    @ObservedObject var pane: PaneState
    @EnvironmentObject private var app: AppState
    let isActive: Bool

    var body: some View {
        VStack(spacing: 0) {
            if app.showTabBar {
                TabStrip(pane: pane)
            }

            if let tab = pane.activeTab {
                if app.showPathBar {
                    PathBar(pane: pane, tab: tab)
                    Rectangle()
                        .fill(Palette.border)
                        .frame(height: 1)
                }

                TabContentView(tab: tab, pane: pane)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if app.showStatusBar {
                    StatusBar(tab: tab)
                }
            } else {
                EmptyFolderView(message: L("No Selection"))
            }
        }
        .background(Palette.panel)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(isActive ? Color.accentColor : Color.clear)
                .frame(height: 2)
                .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture().onEnded {
                app.activate(pane)
            }
        )
    }
}

private struct TabContentView: View {
    @ObservedObject var tab: BrowserTab
    @ObservedObject var pane: PaneState

    var body: some View {
        switch tab.viewMode {
        case .icons:
            IconGridView(tab: tab, pane: pane)
        case .columns:
            MillerView(tab: tab, pane: pane)
        case .list:
            FileListView(tab: tab, pane: pane)
        }
    }
}
