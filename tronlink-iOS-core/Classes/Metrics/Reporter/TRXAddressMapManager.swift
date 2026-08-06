import Foundation

let Metrics_Address_Map_Key = "TRXAddressRandomIdMapping"
let Metrics_Address_Map_Pending_Key = "TRXAddressRandomIdMappingPending"
let Metrics_Address_Map_Removed_Key = "TRXAddressRandomIdMappingRemoved"

protocol TRXAddressMappingStore: AnyObject {
    func saveAddressMappings(_ mapping: [String: String], deletingMetricsFor removedIds: Set<String>) -> Bool
    func loadAllAddressMappings() -> [String: String]?
}

extension TRXMetricsDBManager: TRXAddressMappingStore {}

public final class TRXAddressMapManager {
    public static let shared = TRXAddressMapManager()
    private var mapping: [String: String] = [:]   // address -> id (UUID string)
    private var usedIds: Set<String> = []        // Quick duplicate check
    private let queue = DispatchQueue(label: "com.tron.wallet.AddressMapManager", attributes: .concurrent)
    private let persistenceQueue = DispatchQueue(label: "com.tron.wallet.AddressMapManager.persistence")
    private let store: TRXAddressMappingStore
    private let defaults: UserDefaults
    private var persistenceDisabled = false

    private convenience init() {
        self.init(store: TRXMetricsDBManager.shared, defaults: .standard)
    }

    init(store: TRXAddressMappingStore, defaults: UserDefaults) {
        self.store = store
        self.defaults = defaults

        // Make one best-effort migration of legacy defaults. Whether it succeeds or not,
        // remove the old plaintext copy immediately. On failure the main app's existing
        // generateMappings(forAllAddresses:) launch call creates replacement UUIDs.
        if let legacy = defaults.dictionary(forKey: Metrics_Address_Map_Key) as? [String: String],
           defaults.bool(forKey: Metrics_Address_Map_Pending_Key) || !legacy.isEmpty {
            let removedIds = Set(defaults.stringArray(forKey: Metrics_Address_Map_Removed_Key) ?? [])
            if store.saveAddressMappings(legacy, deletingMetricsFor: removedIds) {
                mapping = legacy
                usedIds = Set(legacy.values)
            } else {
                NSLog("[AddressMap] legacy migration failed, mappings will be regenerated")
            }
            clearLegacySnapshot()
        } else if let stored = store.loadAllAddressMappings() {
            // Clear malformed or stale legacy values even when there is no valid snapshot.
            clearLegacySnapshot()
            mapping = stored
            usedIds = Set(stored.values)
        } else {
            clearLegacySnapshot()
            // The table could not be read. Start empty so IDs still resolve this session,
            // but never write back: a full save from an empty map would delete the mappings
            // that are still on disk and orphan their metrics permanently.
            persistenceDisabled = true
            NSLog("[AddressMap] mapping load failed, persistence disabled for this session")
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
            if let snap = snapshot {
                self.persistenceQueue.sync {
                    self.persistMapping(snap)
                }
            }
            if let cb = completion {
                DispatchQueue.main.async { cb() }
            }
        }
    }

    // MARK: - Obtain the ID corresponding to the address
    /// For a new address this blocks the calling thread on one database save attempt before
    /// exposing the ID. A failed save leaves the ID available in memory for this process.
    public func id(for address: String) -> String {
        let normalized = Self.normalizeAddress(address)
        var existing: String?
        queue.sync { existing = mapping[normalized] }
        if let v = existing { return v }

        var result = Self.generateUUIDFull()
        // Persist before the UID becomes visible to metrics writers.
        queue.sync(flags: .barrier) {
            if let v = self.mapping[normalized] { result = v; return }
            while self.usedIds.contains(result) { result = Self.generateUUIDFull() }
            self.mapping[normalized] = result
            self.usedIds.insert(result)
            let snapshot = self.mapping
            self.persistenceQueue.sync {
                self.persistMapping(snapshot)
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
            self.persistenceQueue.sync {
                self.persistMapping(snapshot, removedIds: [id])
            }
        }
    }

    public func resetAllMappings() {
        queue.async(flags: .barrier) {
            let removedIds = self.usedIds
            self.mapping.removeAll()
            self.usedIds.removeAll()
            let snapshot = self.mapping
            self.persistenceQueue.sync {
                self.persistMapping(snapshot, removedIds: removedIds)
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
        return trimmed
    }

    /// Must run on `persistenceQueue`. Lock order is `queue` (barrier) → `persistenceQueue`
    /// → FMDatabaseQueue; nothing reached from here may call back into this manager.
    private func persistMapping(_ snapshot: [String: String], removedIds: Set<String> = []) {
        guard !persistenceDisabled else { return }
        guard store.saveAddressMappings(snapshot, deletingMetricsFor: removedIds) else {
            NSLog("[AddressMap] database save failed, %d entries remain in memory", snapshot.count)
            return
        }
    }

    private func clearLegacySnapshot() {
        defaults.removeObject(forKey: Metrics_Address_Map_Key)
        defaults.removeObject(forKey: Metrics_Address_Map_Removed_Key)
        defaults.removeObject(forKey: Metrics_Address_Map_Pending_Key)
    }
}
