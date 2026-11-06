import SwiftUI
import AppKit

struct Breadcrumb: View {
    let url: URL
    let onNavigate: (URL) -> Void
    var onCopyPath: (URL) -> Void = { _ in }

    private struct Crumb {
        let name: String
        let url: URL?
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            row(compact: 0)
            row(compact: 3)
            row(compact: 2)
            parentAndCurrentRow
            currentOnlyRow
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
    }

    private var parentAndCurrentRow: some View {
        let all = fullCrumbs
        return HStack(spacing: 1) {
            if all.count >= 2, let parent = all.dropLast().last, let target = parent.url {
                Button {
                    onNavigate(target)
                } label: {
                    crumbLabel(parent.name, current: false)
                }
                .buttonStyle(.plain)
                .help(target.path)

                Image(systemName: "chevron.right")
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundStyle(Palette.textTertiary.opacity(0.8))
            }

            if let last = all.last, let target = last.url {
                Button {
                    onCopyPath(target)
                } label: {
                    crumbLabel(last.name, current: true)
                }
                .buttonStyle(.plain)
                .help(L("Click to copy path"))
            }
        }
        .padding(.vertical, 2)
        .fixedSize(horizontal: true, vertical: false)
    }

    private var currentOnlyRow: some View {
        HStack(spacing: 1) {
            if let last = fullCrumbs.last, let target = last.url {
                Button {
                    onCopyPath(target)
                } label: {
                    crumbLabel(last.name, current: true)
                }
                .buttonStyle(.plain)
                .help(L("Click to copy path"))
            }
        }
        .padding(.vertical, 2)
        .fixedSize(horizontal: true, vertical: false)
    }

    private func row(compact count: Int) -> some View {
        let all = fullCrumbs
        let visible: [Crumb]
        let omitted: [Crumb]

        if count == 0 || all.count <= count + 2 {
            visible = all
            omitted = []
        } else {
            visible = [all[0], Crumb(name: "…", url: nil)] + Array(all.suffix(count))
            omitted = Array(all.dropFirst().dropLast(count))
        }

        return HStack(spacing: 1) {
            ForEach(Array(visible.enumerated()), id: \.offset) { index, crumb in
                if index > 0 {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 7, weight: .semibold))
                        .foregroundStyle(Palette.textTertiary.opacity(0.8))
                }

                if let target = crumb.url {
                    let isCurrent = index == visible.count - 1
                    Button {
                        if isCurrent {
                            onCopyPath(target)
                        } else {
                            onNavigate(target)
                        }
                    } label: {
                        crumbLabel(crumb.name, current: isCurrent)
                    }
                    .buttonStyle(.plain)
                    .help(isCurrent ? L("Click to copy path") : target.path)
                    .contextMenu {
                        Button(L("Copy Path")) {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(target.path, forType: .string)
                        }
                        if isCurrent {
                            Button(L("Copy Full Path")) { onCopyPath(target) }
                        }
                    }
                } else {
                    Menu {
                        ForEach(Array(omitted.enumerated()), id: \.offset) { _, hidden in
                            if let target = hidden.url {
                                Button(hidden.name) { onNavigate(target) }
                            }
                        }
                    } label: {
                        crumbLabel("…", current: false)
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                }
            }
        }
        .padding(.vertical, 2)
        .fixedSize(horizontal: true, vertical: false)
    }

    private func crumbLabel(_ name: String, current: Bool) -> some View {
        Text(name)
            .font(.system(size: 11.5, weight: current ? .semibold : .regular))
            .foregroundStyle(current ? Palette.text : Palette.textSecondary)
            .lineLimit(1)
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(current ? Palette.panel : Color.clear)
            )
            .contentShape(Rectangle())
    }

    private var fullCrumbs: [Crumb] {
        let components = url.pathComponents
        guard components.count > 1 else {
            return [Crumb(name: FileManager.default.displayName(atPath: "/"), url: URL(fileURLWithPath: "/"))]
        }
        var result: [Crumb] = [
            Crumb(name: FileManager.default.displayName(atPath: "/"), url: URL(fileURLWithPath: "/"))
        ]
        var current = URL(fileURLWithPath: "/")
        for component in components.dropFirst() {
            current.appendPathComponent(component)
            let name = current.lastPathComponent == ".Trash"
                ? L("Trash")
                : FileManager.default.displayName(atPath: current.path)
            result.append(Crumb(name: name, url: current))
        }
        return result
    }
}
