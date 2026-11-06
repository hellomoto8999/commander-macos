import SwiftUI

/// Stato separato per lo zoom: non fa parte di AppState, così pinch e slider
/// non provocano il re-render di toolbar, menu e contenuto principale.
final class ZoomState: ObservableObject {
    @Published var iconSize: Double {
        didSet { schedulePersist() }
    }

    private static let key = "pref.iconSize"
    private let defaults = UserDefaults.standard
    private var saveWork: DispatchWorkItem?

    init() {
        let stored = defaults.double(forKey: Self.key)
        iconSize = stored >= 48 ? min(160, max(48, stored)) : 76
    }

    private func schedulePersist() {
        saveWork?.cancel()
        let value = iconSize
        let work = DispatchWorkItem { [weak self] in
            self?.defaults.set(value, forKey: Self.key)
        }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }
}
