# Commander

A native, dual-pane file manager for macOS with a Finder-style interface: system chrome, translucent sidebar, icon/list/column views, persistent tabs, Quick Look previews, and support for volumes, cloud folders, and network shares.

> Inspired by OneCommander (Tangible Loop LLC). Independent macOS project, not affiliated.

![Commander](docs/screenshot.png)

### Views

| Icons | Detailed list | Columns |
|---|---|---|
| ![Icon view](docs/screenshot.png) | ![Detailed list](docs/screenshot-list.png) | ![Column view](docs/screenshot-columns.png) |

## Features

- **Finder-style interface**: automatic light/dark theme based on macOS, system materials (sidebar, headers, bars), semantic colors and system accent color; unified toolbar and centered title.
- **Preview pane hidden by default**, available from Settings, View, or View Options.
- **Resizable window** down to 640×420, with draggable sidebar and preview dividers; sizes are remembered between sessions.
- **Interactive path bar**: every segment navigates; click the current folder, the copy icon, or the context menu to copy the full path.
- **Finder-style sidebar**: colored system icons, Favorites, Cloud, Locations and Tags sections; drag to reorder favorites; resizable and persistent width; tags open a Spotlight search in the home folder.
- **Three views**: icons with Quick Look thumbnails, Miller columns, and a detailed list with adaptive columns (name, date modified, size, kind).
- **Quick Look thumbnails** in icon view for images, PDFs, videos, documents, text files, and Markdown.
- **Zoom**: status-bar slider and pinch-to-zoom in icon view, with persistent icon size.
- **Dual pane** with active pane and adjustable split.
- **Multiple tabs per pane**, restored at launch.
- **Sorting** directly from the toolbar (name, kind, size, date) and from list headers.
- **Network**: Bonjour discovery of SMB/AFP/NFS servers with IP resolution, Finder-script mounting without opening a Finder window, inline connection errors, and mounted network volumes. NFS asks for the export path.
- **Volumes and cloud**: internal/external disks, network shares, Google Drive/OneDrive/Dropbox in CloudStorage, and iCloud Drive.
- **Eject** removable devices from the sidebar, context menu, or with `⌘E`.
- **Preview** of images, PDFs, text, folders, video/audio; Quick Look with the space bar.
- **Sharing** through the system sharing panel.
- **File operations**: copy, cut, paste (including to/from Finder), move here, duplicate, rename, new folder/file, compress to ZIP, make alias, move to Trash, empty Trash, permanently delete.
- **Finder tags** read and write (seven system colors), with a Tags sidebar and tag search.
- **Trash**: if macOS has not granted access, Commander shows Full Disk Access guidance instead of a raw error.
- **Progress panel** for copy and move: current file, bytes transferred, completed items, and Cancel. Same-volume moves are instant.
- **Drag & drop** between panes, onto folders and the sidebar; hold `⌥` to copy.
- **In-folder filter**, optional subfolder search, and Finder color tags.
- **Finder context menus**: Open, Open in New Tab, Paste Item, Get Info, Rename, Compress, Duplicate, Make Alias, Quick Look, Copy, Move to Trash, Share, tag color dots, Customize Folder, Quick Actions, Folder Actions, New Terminal, New Terminal Tab, and installed services (for example Unlock App). Hold **Command or Option** while opening the menu for the Finder alternate commands: Open in New Window, Show Inspector, Duplicate Exactly (with Shift), Slideshow, Copy as Pathname, Delete Immediately, Always Open With, and Show Package Contents. Hold **Control** for Get Summary Info.
- **Get Info**: for a single file or folder it opens the real Finder Info window (Automation permission required); multiple selections or denied Automation fall back to the native info panel.
- **Settings in Finder style**: General, Sidebar, Tags, Advanced, Shortcuts, and Info tabs; startup folder, open folders in tabs, extensions, relative dates, icon previews and item info, warnings, subfolder search, bar visibility, sidebar groups, and custom tags.
- **View Options** with `⌘J`.
- **Keyboard type-ahead**: type the first letters of a name to select the matching item, as in Finder.
- **Finder/Commander shortcuts**, including sidebar and view shortcuts.

## Requirements

- macOS 15 or later.
- Swift 6 / Command Line Tools (Xcode is not required for the current build).
- With Command Line Tools only, the build script automatically uses SDK 26.5 because SDK 27 requires the SwiftUI macro plugin bundled with Xcode.
- Local network access is required for Bonjour server discovery.
- “Get Info” requires Automation permission to control Finder; macOS asks on first use. If denied, Commander shows its native info panel.

## Installation

Download the latest release: [Commander 1.0.1](https://github.com/hellomoto8999/commander-macos/releases/tag/v1.0.1).

- **Requirements:** macOS 15 or later, Apple Silicon
- **Version:** 1.0.1

The app is **ad-hoc signed** and **not notarized** by Apple. On first launch macOS may show the Gatekeeper warning:

1. **Right-click → Open** on `Commander.app`
2. or go to **System Settings → Privacy & Security → Open Anyway**
3. or, from Terminal:
   ```bash
   xattr -dr com.apple.quarantine /Applications/Commander.app
   ```

Removing the warning permanently requires an Apple **Developer ID** signature and notarization.

## Build

```bash
./scripts/build-app.sh          # release
./scripts/build-app.sh debug    # debug
open dist/Commander.app
```

Or:

```bash
make build
make run
```

## Main Shortcuts

| Action | Shortcut |
|---|---|
| Change pane | `Tab` / `⇧Tab` |
| New tab / close tab | `⌘T` / `⌘W` |
| New folder / new file | `⌘⇧N` / `⌃⌘N` |
| Rename | `Return` |
| Open | `⌘↓` or `⌘O` |
| Get Info / inspector | `⌘I` / `⌥⌘I` |
| Make Alias | `⌃⌘A` |
| Quick Look | `Space` or `⌘Y` |
| Move to Trash / empty / permanently delete | `⌘⌫` / `⌘⇧⌫` / `⌘⌥⌫` |
| Move here (after Copy) | `⌥⌘V` |
| Go to Folder | `⌘⇧G` or `⌘L` |
| Back / Forward | `⌘[` / `⌘]` |
| Enclosing Folder | `⌘↑` |
| Enclosing Folder in New Tab | `⌘⇧↑` |
| Icons / List / Columns | `⌘1` / `⌘2` / `⌘3` |
| Connect to Server | `⌘K` |
| Eject volume | `⌘E` |
| Dual pane | `⌘⌥D` |
| Sidebar / preview | `⌘⌥S` / `⌘⌥P` |
| Show/hide toolbar | `⌘⌥T` |
| Status bar | `⌘/` |
| View Options | `⌘J` |
| Settings | `⌘,` |
| Hidden files | `⌘⇧.` |
| Refresh | `⌘R` |
| First / last item | `Home` / `End` |
| Extend to first / last | `⇧Home` / `⇧End` |
| Page up / page down | `Page Up` / `Page Down` |
| Type-ahead | Type the item name |
| Arrows | Navigate; hold `⇧` to extend selection |

## Mouse Gestures

| Gesture | Action |
|---|---|
| Click | Select; in column view, open the folder |
| Double-click | Open file or folder |
| Right-click / Control-click | Finder context menu for the item |
| `⌥` + right-click | Extended menu: path, package contents, always open with |
| Middle-click | Open folder in a new tab / open file |
| `⌘`-click | Toggle selection |
| `⇧`-click | Select a range |
| `⌘`-double-click | Open folder in a new tab |
| `⌥`-double-click | Open folder in the other pane |
| Drag | Move; hold `⌥` to copy; drags the whole selection |
| Click background | Deselect |
| Right-click background | Folder menu (new folder, paste, sort…) |
| Click current path crumb | Copy the full path |
| Click copy icon in path bar | Copy the full path |
| Two-finger swipe / side mouse buttons | Back / forward |
| Pinch | Zoom icons |

Back/forward also work from the toolbar and with `⌘[` / `⌘]`.

## Project Structure

```
Sources/Commander/
├── CommanderApp.swift        # SwiftUI app, window, AppDelegate
├── CommanderCommands.swift   # Menus and shortcuts
├── Models/
│   ├── AppState.swift        # Global state, file operations, volumes, network
│   ├── BrowserTab.swift      # Tab: columns, selection, history
│   ├── PaneState.swift       # Pane with tabs
│   └── FileItem.swift        # Item metadata
├── Services/
│   ├── FileSystem.swift      # Listing, copy/move/rename, Trash
│   ├── NetworkBrowser.swift  # Bonjour SMB/AFP/NFS discovery
│   ├── FileInfoPanel.swift   # Info panel / Finder Info
│   ├── IconProvider.swift    # System icon cache
│   ├── ThumbnailProvider.swift
│   ├── QuickLook.swift
│   └── KeyMonitor.swift
├── Support/
│   ├── Localization.swift    # English/Italian based on system language
│   ├── Theme.swift           # macOS semantic colors
│   └── Format.swift
└── Views/
    ├── MainToolbar.swift     # Unified toolbar
    ├── SidebarView.swift     # Favorites, cloud, volumes, network, tags
    ├── IconGridView.swift    # Icon view + zoom
    ├── MillerView.swift      # Miller columns
    ├── FileListView.swift    # Detailed list
    └── …
```

## Notes

- The app is not sandboxed, so it can freely manage user-selected files.
- The signature is ad-hoc: distributing to other Macs requires a Developer ID signature and notarization.
- Folder size calculation runs in the background and can take a moment on very large folders.
- Finder’s copy panel is not exposed as a public API: Commander uses an equivalent native panel with progress, current file, and Cancel.
- The interface localization covers English and Italian; other languages fall back to English.
- The Trash is protected by macOS: reading or emptying it from Commander requires Full Disk Access. Without permission the app shows a guide with a button to open System Settings; “Open in Finder” remains available.
- “Make Alias” uses a symbolic link because macOS does not expose a public API for creating Finder aliases.
- The Tags sidebar uses Spotlight (`mdfind`) and searches the home folder; custom tags can be configured in Settings → Tags.
- Settings that depend on system-only features (Desktop icons, automatic 30-day Trash cleanup, iCloud warnings) are not duplicated; the remaining Finder preferences are mapped to Commander features.

## Possible Extensions

- Undoable file operations through `UndoManager`.
- Mass rename with regular expressions.
- Global Spotlight search.
- Custom scripts and automations.
- Gallery view.

## License

Released under the **MIT License**. See [LICENSE](LICENSE).
