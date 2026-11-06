import Foundation
import AppKit
import Darwin

struct NetworkServer: Identifiable, Hashable {
    let id: String
    let name: String
    let type: String
    var host: String
    let scheme: String

    /// Bonjour a volte restituisce soltanto il nome visuale del servizio
    /// ("omv - SMB/CIFS"): non è un hostname valido e non può finire in una URL.
    var hasValidHost: Bool {
        !host.isEmpty &&
            host.rangeOfCharacter(from: .whitespacesAndNewlines) == nil &&
            !host.contains("[") &&
            !host.contains("]")
    }

    var connectHost: String {
        guard hasValidHost else { return host }
        if host.contains(":") { return "[\(host)]" }
        if host.contains(".") { return host }
        return host + ".local"
    }
}

/// Scoperta Bonjour dei server file (SMB/AFP/NFS) sulla rete locale.
final class NetworkBrowser: NSObject, ObservableObject, NetServiceBrowserDelegate, NetServiceDelegate {
    @Published private(set) var servers: [NetworkServer] = []
    @Published private(set) var isBrowsing = false

    private var browsers: [NetServiceBrowser] = []
    private var resolvingServices: [String: NetService] = [:]
    private var started = false

    func start() {
        guard !started else { return }
        started = true
        for type in ["_smb._tcp.", "_afp._tcp.", "_nfs._tcp."] {
            let browser = NetServiceBrowser()
            browser.delegate = self
            browser.searchForServices(ofType: type, inDomain: "local.")
            browsers.append(browser)
        }
    }

    func stop() {
        guard started else { return }
        for browser in browsers { browser.stop() }
        browsers.removeAll()
        resolvingServices.removeAll()
        started = false
        isBrowsing = false
    }

    func refresh() {
        stop()
        servers.removeAll()
        start()
    }

    // MARK: NetServiceBrowserDelegate

    func netServiceBrowserWillSearch(_ browser: NetServiceBrowser) {
        isBrowsing = true
    }

    func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
        isBrowsing = false
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String: NSNumber]) {
        isBrowsing = false
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        let identifier = "\(service.type)|\(service.name)"
        guard !servers.contains(where: { $0.id == identifier }) else { return }

        let scheme: String
        if service.type.hasPrefix("_afp") { scheme = "afp" }
        else if service.type.hasPrefix("_nfs") { scheme = "nfs" }
        else { scheme = "smb" }

        servers.append(NetworkServer(
            id: identifier,
            name: service.name,
            type: service.type,
            host: (service.hostName ?? service.name)
                .trimmingCharacters(in: CharacterSet(charactersIn: ".")),
            scheme: scheme
        ))
        servers.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

        // NetService deve restare vivo mentre risolve: senza questa referenza
        // il callback non arriva mai e l'host rimane il nome visuale.
        resolvingServices[identifier] = service
        service.delegate = self
        service.resolve(withTimeout: 6)
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        let identifier = "\(service.type)|\(service.name)"
        servers.removeAll { $0.id == identifier }
        resolvingServices.removeValue(forKey: identifier)
    }

    // MARK: NetServiceDelegate

    func netServiceDidResolveAddress(_ sender: NetService) {
        let identifier = "\(sender.type)|\(sender.name)"
        guard let index = servers.firstIndex(where: { $0.id == identifier }) else { return }

        // L'indirizzo numerico è più affidabile del nome Bonjour: alcuni
        // server pubblicano nomi visivi con spazi o caratteri non validi.
        var resolved: String?
        if let addresses = sender.addresses {
            let ipv4 = addresses.first { addressFamily(of: $0) == sa_family_t(AF_INET) }
            if let address = ipv4 ?? addresses.first {
                resolved = numericHost(from: address)
            }
        }

        if resolved == nil, let hostName = sender.hostName {
            let trimmed = hostName.trimmingCharacters(in: CharacterSet(charactersIn: "."))
            if !trimmed.isEmpty, !trimmed.contains(" ") {
                resolved = trimmed
            }
        }

        if let resolved {
            servers[index].host = resolved
        }
        resolvingServices.removeValue(forKey: identifier)
    }

    func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        // Si mantiene il nome del servizio come host di ripiego. Se non è un
        // hostname valido l'interfaccia chiederà di inserire l'indirizzo.
        resolvingServices.removeValue(forKey: "\(sender.type)|\(sender.name)")
    }

    // MARK: - Risoluzione indirizzi

    private func addressFamily(of data: Data) -> sa_family_t {
        data.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return sa_family_t(AF_UNSPEC) }
            return base.assumingMemoryBound(to: sockaddr.self).pointee.sa_family
        }
    }

    private func numericHost(from data: Data) -> String? {
        data.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return nil }
            let address = base.assumingMemoryBound(to: sockaddr.self)
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let result = getnameinfo(
                address,
                socklen_t(address.pointee.sa_len),
                &host,
                socklen_t(host.count),
                nil,
                0,
                NI_NUMERICHOST
            )
            guard result == 0 else { return nil }
            let value = String(cString: host)
            // Gli indirizzi IPv6 link-local non sono utilizzabili senza scope.
            return value.lowercased().hasPrefix("fe80:") ? nil : value
        }
    }
}
