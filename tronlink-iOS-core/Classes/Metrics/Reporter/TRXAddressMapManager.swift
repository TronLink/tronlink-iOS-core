import Foundation
import UIKit

let Metrics_Address_Map_Key = "TRXAddressRandomIdMapping"
private let Metrics_Address_Map_Pending_Key = "TRXAddressRandomIdMappingPending"

public final class TRXAddressMapManager {
    public static let shared = TRXAddressMapManager()
    private var mapping: [String: String] = [:]   // address -> id (UUID string)
    private var usedIds: Set<String> = []        // Quick duplicate check
    private let queue = DispatchQueue(label: "com.tron.wallet.AddressMapManager", attributes: .concurrent)
    private let persistenceQueue = DispatchQueue(label: "com.tron.wallet.AddressMapManager.persistence")
    private var pendingMappingsSnapshot: [String: String]?
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
            if TRXMetricsDBManager.shared.saveAddressMappings(legacy) {
                clearPendingSnapshot()
            }
        } else {
            let stored = TRXMetricsDBManager.shared.loadAllAddressMappings()
            mapping = stored
            usedIds = Set(stored.values)
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
            if let cb = completion {
                DispatchQueue.main.async { cb() }
            }
            if let snap = snapshot {
                self.persistenceQueue.async {
                    self.persistMapping(snap)
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
        // Only mutate in-memory state inside the sync barrier (fast, no I/O).
        // The queue lock is released as soon as the barrier block returns.
        queue.sync(flags: .barrier) {
            if let v = self.mapping[normalized] { result = v; return }
            while self.usedIds.contains(result) { result = Self.generateUUIDFull() }
            self.mapping[normalized] = result
            self.usedIds.insert(result)
            let snapshot = self.mapping
            self.persistenceQueue.async {
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
            self.persistenceQueue.async {
                self.persistMapping(snapshot)
            }
        }
    }

    public func resetAllMappings() {
        queue.async(flags: .barrier) {
            self.mapping.removeAll()
            self.usedIds.removeAll()
            let snapshot = self.mapping
            self.persistenceQueue.async {
                self.persistMapping(snapshot)
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

    private func persistMapping(_ snapshot: [String: String], retryAttempt: Int = 0) {
        pendingMappingsSnapshot = snapshot
        if TRXMetricsDBManager.shared.saveAddressMappings(snapshot) {
            pendingMappingsSnapshot = nil
            clearPendingSnapshot()
            return
        }

        guard retryAttempt < Self.persistenceRetryDelays.count else {
            savePendingSnapshot(snapshot)
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

    private func savePendingSnapshot(_ snapshot: [String: String]) {
        UserDefaults.standard.set(snapshot, forKey: Metrics_Address_Map_Key)
        UserDefaults.standard.set(true, forKey: Metrics_Address_Map_Pending_Key)
    }

    private func clearPendingSnapshot() {
        UserDefaults.standard.removeObject(forKey: Metrics_Address_Map_Key)
        UserDefaults.standard.removeObject(forKey: Metrics_Address_Map_Pending_Key)
    }
}
