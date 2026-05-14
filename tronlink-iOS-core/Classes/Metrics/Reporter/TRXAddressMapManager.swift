import Foundation

let Metrics_Address_Map_Key = "TRXAddressRandomIdMapping"

public final class TRXAddressMapManager {
    public static let shared = TRXAddressMapManager()
    private var mapping: [String: String] = [:]   // address -> id (UUID string)
    private var usedIds: Set<String> = []        // Quick duplicate check
    private let queue = DispatchQueue(label: "com.tron.wallet.AddressMapManager", attributes: .concurrent)
    private let persistenceQueue = DispatchQueue(label: "com.tron.wallet.AddressMapManager.persistence")

    private init() {
        // Migrate legacy UserDefaults data to FMDB on first launch after upgrade.
        // Only clear UserDefaults once the DB write succeeds, so the migration retries
        // on the next launch if the write fails (e.g. disk full).
        if let legacy = UserDefaults.standard.dictionary(forKey: Metrics_Address_Map_Key) as? [String: String],
           !legacy.isEmpty {
            mapping = legacy
            usedIds = Set(legacy.values)
            if TRXMetricsDBManager.shared.saveAddressMappings(legacy) {
                UserDefaults.standard.removeObject(forKey: Metrics_Address_Map_Key)
            }
        } else {
            let stored = TRXMetricsDBManager.shared.loadAllAddressMappings()
            mapping = stored
            usedIds = Set(stored.values)
        }
    }

    // MARK: - generate mapping relationship
    public func generateMappings(forAllAddresses addresses: [String], completion: (() -> Void)? = nil) {
        let normalizedSet = Set(addresses.map { Self.normalizeAddress($0) })
        queue.async(flags: .barrier) {
            var changed = false
            for addr in normalizedSet {
                if self.mapping[addr] == nil {
                    var newId = Self.generateUUIDFull()
                    while self.usedIds.contains(newId) {
                        newId = Self.generateUUIDFull()
                    }
                    self.mapping[addr] = newId
                    self.usedIds.insert(newId)
                    changed = true
                }
            }
            let snapshot = changed ? self.mapping : nil
            if let cb = completion {
                DispatchQueue.main.async { cb() }
            }
            if let snap = snapshot {
                self.persistenceQueue.async {
                    TRXMetricsDBManager.shared.saveAddressMappings(snap)
                }
            }
        }
    }

    // MARK: - Obtain the ID corresponding to the address
    public func id(for address: String) -> String {
        let normalized = Self.normalizeAddress(address)
        var existing: String?
        queue.sync { existing = mapping[normalized] }
        if let v = existing { return v }

        var result = Self.generateUUIDFull()
        var needsSave = false
        // Only mutate in-memory state inside the sync barrier (fast, no I/O).
        // The queue lock is released as soon as the barrier block returns.
        queue.sync(flags: .barrier) {
            if let v = self.mapping[normalized] { result = v; return }
            while self.usedIds.contains(result) { result = Self.generateUUIDFull() }
            self.mapping[normalized] = result
            self.usedIds.insert(result)
            needsSave = true
        }
        // Persist asynchronously on a serial queue so DB writes keep the same
        // order as the in-memory mutations.
        if needsSave {
            let uuid = result
            persistenceQueue.async {
                TRXMetricsDBManager.shared.upsertAddressMapping(address: normalized, uuid: uuid)
            }
        }
        return result
    }

    // MARK: - Delete/Reset
    public func removeMapping(for address: String) {
        let normalized = Self.normalizeAddress(address)
        queue.async(flags: .barrier) {
            guard let id = self.mapping.removeValue(forKey: normalized) else { return }
            self.usedIds.remove(id)
            let snapshot = self.mapping
            self.persistenceQueue.async {
                TRXMetricsDBManager.shared.saveAddressMappings(snapshot)
            }
        }
    }

    public func resetAllMappings() {
        queue.async(flags: .barrier) {
            self.mapping.removeAll()
            self.usedIds.removeAll()
            let snapshot = self.mapping
            self.persistenceQueue.async {
                TRXMetricsDBManager.shared.saveAddressMappings(snapshot)
            }
        }
    }

    // Obtain the mapping of all addresses
    public func allMappings() -> [String: String] {
        var snap: [String: String] = [:]
        queue.sync { snap = self.mapping }
        return snap
    }

    private static func generateUUIDFull() -> String {
        return UUID().uuidString
    }

    private static func normalizeAddress(_ addr: String) -> String {
        let trimmed = addr.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = trimmed.lowercased()
        if lowercased.hasPrefix("0x") || lowercased.hasPrefix("41") {
            return lowercased.drop0x
        }
        return trimmed
    }
}
