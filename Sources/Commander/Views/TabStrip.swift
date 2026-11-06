import SwiftUI
import AppKit

struct TabStrip: View {
    @ObservedObject var pane: PaneState
    @EnvironmentObject private var app: AppState

    var body: some View {
        HStack(spacing: 3) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 3) {
                    ForEach(pane.tabs) { tab in
                        TabChip(pane: pane, tab: tab, active: pane.activeTab?.id == tab.id)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
            }
            .frame(height: 36)

            Button {
                pane.newTab()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(L("New Tab"))
            .padding(.trailing, 8)

            Spacer(minLength: 0)
        }
        .frame(height: 36)
        .background(VisualEffectBackground(material: .headerView))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Palette.border)
                .frame(height: 1)
        }
    }
}

struct TabChip: View {
    @ObservedObject var pane: PaneState
    @ObservedObject var tab: BrowserTab
    let active: Bool

    @State private var hover = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "folder.fill")
                .font(.system(size: 10))
                .foregroundStyle(active ? Color.secondary : Color(nsColor: .tertiaryLabelColor))

            Text(tab.title)
                .font(.system(size: 11.5, weight: active ? .medium : .regular))
                .foregroundStyle(active ? Palette.text : Palette.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)

            if tab.isLoading {
                ProgressView()
                    .controlSize(.mini)
                    .scaleEffect(0.65)
                    .frame(width: 11, height: 11)
            } else if pane.tabs.count > 1 && (hover || active) {
                Button {
                    pane.closeTab(tab)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 7.5, weight: .bold))
                        .foregroundStyle(Palette.textSecondary)
                        .frame(width: 13, height: 13)
                        .background(Circle().fill(hover ? Palette.rowHover : Color.clear))
                }
                .buttonStyle(.plain)
                .help(L("Close Tab"))
            }
        }
        .padding(.leading, 8)
        .padding(.trailing, 6)
        .frame(maxWidth: 185, minHeight: 26)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(active ? Palette.panel : (hover ? Palette.rowHover : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(active ? Palette.border : Color.clear, lineWidth: 0.5)
        )
        .contentShape(Rectangle())
        .onHover { hover = $0 }
        .onTapGesture {
            pane.activateTab(tab)
        }
        .contextMenu {
            Button(L("Close Tab")) { pane.closeTab(tab) }
                .disabled(pane.tabs.count <= 1)
            Button(L("Close Other Tabs")) {
                for other in pane.tabs where other.id != tab.id {
                    pane.closeTab(other)
                }
            }
            .disabled(pane.tabs.count <= 1)
            Divider()
            Button(L("New Tab")) { pane.newTab() }
        }
    }
}
