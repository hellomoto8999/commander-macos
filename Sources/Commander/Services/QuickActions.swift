import AppKit

/// Scopre i Quick Action / Servizi di Automator installati e li esegue
/// tramite NSPerformService, senza passare dal Finder.
enum QuickActionRunner {
    struct Action: Identifiable {
        let id: String
        let name: String
        let workflowURL: URL
        let requiresFinder: Bool
    }

    static func discover() -> [Action] {
        let fm = FileManager.default
        let directories = [
            fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Services"),
            URL(fileURLWithPath: "/Library/Services"),
            URL(fileURLWithPath: "/System/Library/Services")
        ]
        var result: [Action] = []
        var seen = Set<String>()

        for directory in directories {
            guard let entries = try? fm.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for workflow in entries where workflow.pathExtension == "workflow" {
                let infoURL = workflow.appendingPathComponent("Contents/Info.plist")
                guard let data = try? Data(contentsOf: infoURL),
                      let plist = try? PropertyListSerialization.propertyList(
                        from: data,
                        options: [],
                        format: nil
                      ) as? [String: Any],
                      let services = plist["NSServices"] as? [[String: Any]] else { continue }

                for service in services {
                    guard let menu = service["NSMenuItem"] as? [String: Any],
                          let name = menu["default"] as? String,
                          !name.isEmpty,
                          seen.insert(name).inserted else { continue }
                    let context = service["NSRequiredContext"] as? [String: Any]
                    let requiresFinder = (context?["NSApplicationIdentifier"] as? String) == "com.apple.finder"
                    result.append(Action(
                        id: "\(workflow.path)|\(name)",
                        name: name,
                        workflowURL: workflow,
                        requiresFinder: requiresFinder
                    ))
                }
            }
        }
        return result.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    @discardableResult
    static func perform(_ action: Action, on urls: [URL]) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(urls as [NSURL])
        return NSPerformService(action.name, pasteboard)
    }
}
