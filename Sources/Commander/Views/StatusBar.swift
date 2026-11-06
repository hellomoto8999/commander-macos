import SwiftUI
import AppKit

struct StatusBar: View {
    @ObservedObject var tab: BrowserTab
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var zoom: ZoomState

    var body: some View {
        HStack(spacing: 6) {
            if tab.isLoading {
                ProgressView()
                    .controlSize(.mini)
                    .scaleEffect(0.6)
                    .frame(width: 11, height: 11)
            }

            Text(L10n.items(tab.visibleItems.count))
                .font(.system(size: 10.5))
                .foregroundStyle(Palette.textSecondary)

            if !tab.selection.isEmpty {
                Text("·")
                    .foregroundStyle(Palette.textTertiary)
                Text(L10n.selected(tab.selection.count))
                    .font(.system(size: 10.5))
                    .foregroundStyle(Palette.textSecondary)

                let size = tab.selectedSize
                if size > 0 {
                    Text(Format.bytes(size))
                        .font(.system(size: 10.5).monospacedDigit())
                        .foregroundStyle(Palette.textTertiary)
                }
            }

            if !tab.filter.isEmpty {
                Text("· \(tab.filter)")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Palette.textTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            if tab.viewMode == .icons {
                HStack(spacing: 4) {
                    Image(systemName: "minus")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(Palette.textTertiary)
                    Slider(value: $zoom.iconSize, in: 48...160, step: 4)
                        .controlSize(.mini)
                        .frame(width: 76)
                    Image(systemName: "plus")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(Palette.textTertiary)
                }
                .help(L("Icon Size"))
                .padding(.trailing, 4)
            }

            if let error = tab.errorText {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(Palette.danger)
                    .help(error)
            }

            if let free = Format.freeSpace(for: tab.currentFolder) {
                Text(free)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Palette.textTertiary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 24)
        .background(VisualEffectBackground(material: .headerView))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Palette.border)
                .frame(height: 1)
        }
    }
}
