import Foundation
import UIKit

let Metrics_Address_Map_Key = "TRXAddressRandomIdMapping"
private let Metrics_Address_Map_Pending_Key = "TRXAddressRandomIdMappingPending"
private let Metrics_Address_Map_Removed_Key = "TRXAddressRandomIdMappingRemoved"

public final class TRXAddressMapManager {
    public static let shared = TRXAddressMapManager()
    private var mapping: [String: String] = [:]   // address -> id (UUID string)
    private var usedIds: Set<String> = []        // Quick duplicate check
    private let queue = DispatchQueue(label: "com.tron.wallet.AddressMapManager", attributes: .concurrent)
    private let persistenceQueue = DispatchQueue(label: "com.tron.wallet.AddressMapManager.persistence")
    private var pendingMappingsSnapshot: [String: String]?
    private var pendingRemovedIds: Set<String> = []
    private var persistenceDisabled = false
    private var backgroundObserver: NSObjectProtocol?
    private static let persistenceRetryDelays: [TimeInterval] = [1, 2, 4]

    private init() {
        // Migrate legacy UserDefaults data to FMDB on first launch after upgrade.
        // Only clear UserDefaults once the DB write succeeds, so the migration retries
        // on the next launch if the write fails (e.g. disk full).
        let defaults = UserDefaults.standard
        if let legacy = defaults.dictionary(forKey: Metrics_Address_Map_Key) as? [String: String],
           defaults.bool(forKey: Metrics_Address_Map_Pending_Key) || !legacy.isEmpty {
            mapping = legacy
            usedIds = Set(legacy.values)
            // The pending snapshot may predate a delete whose cleanup never ran, so replay
            // those removals here instead of leaving the metrics behind as orphans.
            let removedIds = Set(defaults.stringArray(forKey: Metrics_Address_Map_Removed_Key) ?? [])
            if TRXMetricsDBManager.shared.saveAddressMappings(legacy, deletingMetricsFor: removedIds) {
                clearPendingSnapshot()
            } else {
                pendingRemovedIds = removedIds
            }
        } else if let stored = TRXMetricsDBManager.shared.loadAllAddressMappings() {
            mapping = stored
            usedIds = Set(stored.values)
        } else {
            // The table could not be read. Start empty so IDs still resolve this session,
            // but never write back: a full save from an empty map would delete the mappings
            // that are still on disk and orphan their metrics permanently.
            persistenceDisabled = true
            NSLog("[AddressMap] mapping load failed, persistence disabled for this session")
        }

        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.flushPendingMappings()
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
    /// For a new address this blocks the calling thread on a database write, so the ID is
    /// durable before any metrics row can reference it. Do not call from the main thread.
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
    private func persistMapping(_ snapshot: [String: String], removedIds: Set<String> = [], retryAttempt: Int = 0) {
        guard !persistenceDisabled else { return }
        // A newer save supersedes a failed one, so carry its removals forward instead of
        // dropping them along with its snapshot.
        let removals = removedIds.union(pendingRemovedIds)
        pendingMappingsSnapshot = snapshot
        pendingRemovedIds = removals
        if TRXMetricsDBManager.shared.saveAddressMappings(snapshot, deletingMetricsFor: removals) {
            pendingMappingsSnapshot = nil
            pendingRemovedIds = []
            clearPendingSnapshot()
            return
        }

        savePendingSnapshot(snapshot, removedIds: removals)

        guard retryAttempt < Self.persistenceRetryDelays.count else {
            NSLog("[AddressMap] save failed after retries, %d entries preserved", snapshot.count)
            return
        }

        let delay = Self.persistenceRetryDelays[retryAttempt]
        NSLog("[AddressMap] save failed, retry %d in %.0fs", retryAttempt + 1, delay)
        persistenceQueue.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self, self.pendingMappingsSnapshot == snapshot else { return }
            self.persistMapping(snapshot, retryAttempt: retryAttempt + 1)
        }
    }

    private func flushPendingMappings() {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.persistenceQueue.async { [weak self] in
                guard let self = self, let snapshot = self.pendingMappingsSnapshot else { return }
                self.persistMapping(snapshot, retryAttempt: Self.persistenceRetryDelays.count)
            }
        }
    }

    private func savePendingSnapshot(_ snapshot: [String: String], removedIds: Set<String>) {
        UserDefaults.standard.set(snapshot, forKey: Metrics_Address_Map_Key)
        UserDefaults.standard.set(Array(removedIds), forKey: Metrics_Address_Map_Removed_Key)
        UserDefaults.standard.set(true, forKey: Metrics_Address_Map_Pending_Key)
    }

    private func clearPendingSnapshot() {
        UserDefaults.standard.removeObject(forKey: Metrics_Address_Map_Key)
        UserDefaults.standard.removeObject(forKey: Metrics_Address_Map_Removed_Key)
        UserDefaults.standard.removeObject(forKey: Metrics_Address_Map_Pending_Key)
    }
}
