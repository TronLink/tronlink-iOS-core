import XCTest
@testable import TLCore
import TronKeystore

private final class AddressMappingStoreStub: TRXAddressMappingStore {
    var loadResult: [String: String]?
    var saveResults: [Bool]
    private(set) var loadCallCount = 0
    private(set) var saves: [(mapping: [String: String], removedIds: Set<String>)] = []
    private(set) var upserts: [(address: String, uuid: String)] = []

    init(loadResult: [String: String]? = [:], saveResults: [Bool] = [true]) {
        self.loadResult = loadResult
        self.saveResults = saveResults
    }

    func loadAllAddressMappings() -> [String: String]? {
        loadCallCount += 1
        return loadResult
    }

    func saveAddressMappings(_ mapping: [String: String], deletingMetricsFor removedIds: Set<String>) -> Bool {
        saves.append((mapping, removedIds))
        return saveResults.isEmpty ? false : saveResults.removeFirst()
    }

    func upsertAddressMapping(address: String, uuid: String) -> Bool {
        upserts.append((address, uuid))
        return saveResults.isEmpty ? false : saveResults.removeFirst()
    }
}

class Tests: XCTestCase {
    
    private static let uppercaseChars = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
    private static let lowercaseChars = Array("abcdefghijklmnopqrstuvwxyz")
    private static let digitChars = Array("0123456789")
    
    private let password: String = Tests.randomPassword()

    private let datadir = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
    private let keysSubfolder: String = "/keystore"
    
    private lazy var keysDirectory: URL = {
        let keysDirectory = URL(fileURLWithPath: datadir + keysSubfolder)
        return keysDirectory
    }()
    
    private lazy var keyStore: KeyStore = {
        let keyStore = try! KeyStore(keyDirectory: self.keysDirectory)
        return keyStore
    }()
    
    private lazy var tWallet: TWallet = {
        // 18.206.50.220:50051
        // 47.90.214.183:50051
        let fullNode = "18.206.50.220:50051"
//        GRPCCall.useInsecureConnections(forHost: fullNode)
        let tWallet = TWallet.init(host: fullNode)
        return tWallet
    }()

    private static func randomPassword() -> String {
        var generator = SystemRandomNumberGenerator()

        var chars: [Character] = []
        chars.reserveCapacity(8)
        chars.append(uppercaseChars[Int.random(in: 0..<uppercaseChars.count, using: &generator)])
        chars.append(lowercaseChars[Int.random(in: 0..<lowercaseChars.count, using: &generator)])
        for _ in 0..<6 {
            chars.append(digitChars[Int.random(in: 0..<digitChars.count, using: &generator)])
        }

        chars.shuffle(using: &generator)
        return String(chars)
    }
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExample() {
        // This is an example of a functional test case.
        XCTAssert(true, "Pass")
    }

    func testAddressMapLegacyMigrationSucceedsAndClearsDefaults() {
        let (defaults, suite) = makeAddressMapDefaults(testName: #function)
        defer { defaults.removePersistentDomain(forName: suite) }
        let legacy = ["TLegacyAddress": "legacy-uuid"]
        defaults.set(legacy, forKey: Metrics_Address_Map_Key)
        defaults.set(true, forKey: Metrics_Address_Map_Pending_Key)
        defaults.set(["removed-uuid"], forKey: Metrics_Address_Map_Removed_Key)
        let store = AddressMappingStoreStub(saveResults: [true])

        let manager = TRXAddressMapManager(store: store, defaults: defaults)

        XCTAssertEqual(manager.allMappings(), legacy)
        XCTAssertEqual(store.loadCallCount, 0)
        XCTAssertEqual(store.saves.count, 1)
        XCTAssertEqual(store.saves.first?.mapping, legacy)
        XCTAssertEqual(store.saves.first?.removedIds, ["removed-uuid"])
        assertAddressMapDefaultsCleared(defaults)
    }

    func testAddressMapFailedMigrationRegeneratesAndSavesOnce() {
        let (defaults, suite) = makeAddressMapDefaults(testName: #function)
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(["TRegeneratedAddress": "legacy-uuid"], forKey: Metrics_Address_Map_Key)
        defaults.set(true, forKey: Metrics_Address_Map_Pending_Key)
        let store = AddressMappingStoreStub(saveResults: [false, true])

        let manager = TRXAddressMapManager(store: store, defaults: defaults)

        XCTAssertTrue(manager.allMappings().isEmpty)
        XCTAssertEqual(store.saves.count, 1)
        assertAddressMapDefaultsCleared(defaults)

        let generated = expectation(description: "regenerated mapping persisted")
        manager.generateMappings(forAllAddresses: ["TRegeneratedAddress"]) {
            generated.fulfill()
        }
        wait(for: [generated], timeout: 2)

        let replacement = manager.allMappings()["TRegeneratedAddress"]
        XCTAssertNotNil(replacement)
        XCTAssertNotEqual(replacement, "legacy-uuid")
        // Only the newly generated row, and no second full-table replace: the barrier that
        // does this write also stalls the main thread's read in id(for:).
        XCTAssertEqual(store.upserts.map { $0.address }, ["TRegeneratedAddress"])
        XCTAssertEqual(store.upserts.first?.uuid, replacement)
        XCTAssertEqual(store.saves.count, 1)
        assertAddressMapDefaultsCleared(defaults)
    }

    func testAddressMapEmptyPendingSnapshotMigratesOnceAndClearsDefaults() {
        let (defaults, suite) = makeAddressMapDefaults(testName: #function)
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set([String: String](), forKey: Metrics_Address_Map_Key)
        defaults.set(true, forKey: Metrics_Address_Map_Pending_Key)
        defaults.set(["removed-uuid"], forKey: Metrics_Address_Map_Removed_Key)
        let store = AddressMappingStoreStub(saveResults: [true])

        let manager = TRXAddressMapManager(store: store, defaults: defaults)

        XCTAssertTrue(manager.allMappings().isEmpty)
        XCTAssertEqual(store.saves.count, 1)
        XCTAssertEqual(store.saves.first?.mapping, [:])
        XCTAssertEqual(store.saves.first?.removedIds, ["removed-uuid"])
        assertAddressMapDefaultsCleared(defaults)
    }

    func testAddressMapMalformedLegacyDefaultsAreClearedWithoutMigration() {
        let (defaults, suite) = makeAddressMapDefaults(testName: #function)
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(["TBroken": 42], forKey: Metrics_Address_Map_Key)
        defaults.set(true, forKey: Metrics_Address_Map_Pending_Key)
        defaults.set(["stale-removal"], forKey: Metrics_Address_Map_Removed_Key)
        let stored = ["TDatabaseAddress": "database-uuid"]
        let store = AddressMappingStoreStub(loadResult: stored, saveResults: [])

        let manager = TRXAddressMapManager(store: store, defaults: defaults)

        XCTAssertEqual(manager.allMappings(), stored)
        XCTAssertEqual(store.loadCallCount, 1)
        XCTAssertTrue(store.saves.isEmpty)
        assertAddressMapDefaultsCleared(defaults)
    }

    func testAddressMapRuntimeSaveFailureDoesNotRetryOrWriteDefaults() {
        let (defaults, suite) = makeAddressMapDefaults(testName: #function)
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = AddressMappingStoreStub(loadResult: [:], saveResults: [false, true])
        let manager = TRXAddressMapManager(store: store, defaults: defaults)

        let generatedId = manager.id(for: "TRuntimeFailure")

        XCTAssertFalse(generatedId.isEmpty)
        // One row for the new address, never a full-table rewrite: the caller may be the main thread.
        XCTAssertEqual(store.upserts.map { $0.address }, ["TRuntimeFailure"])
        XCTAssertTrue(store.saves.isEmpty)
        assertAddressMapDefaultsCleared(defaults)

        let noRetry = expectation(description: "no delayed retry")
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.2) {
            noRetry.fulfill()
        }
        wait(for: [noRetry], timeout: 2)
        XCTAssertEqual(store.upserts.count, 1)
        XCTAssertTrue(store.saves.isEmpty)
        assertAddressMapDefaultsCleared(defaults)
    }

    func testAddressMapLoadFailureDoesNotOverwriteDatabase() {
        let (defaults, suite) = makeAddressMapDefaults(testName: #function)
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = AddressMappingStoreStub(loadResult: nil, saveResults: [true])
        let manager = TRXAddressMapManager(store: store, defaults: defaults)

        XCTAssertFalse(manager.id(for: "TReadFailure").isEmpty)

        XCTAssertTrue(store.saves.isEmpty)
        // The address may already hold a different UUID on disk; upserting would orphan its metrics.
        XCTAssertTrue(store.upserts.isEmpty)
        assertAddressMapDefaultsCleared(defaults)
    }

    func testAddressMappingTransactionRequiresCommitSuccess() {
        var commitCallCount = 0
        var rollbackCallCount = 0

        let commitFailure = TRXMetricsDBManager.finalizeAddressMappingTransaction(
            statementsSucceeded: true,
            commit: {
                commitCallCount += 1
                return false
            },
            rollback: { rollbackCallCount += 1 }
        )

        XCTAssertFalse(commitFailure)
        XCTAssertEqual(commitCallCount, 1)
        XCTAssertEqual(rollbackCallCount, 1)

        commitCallCount = 0
        rollbackCallCount = 0
        let commitSuccess = TRXMetricsDBManager.finalizeAddressMappingTransaction(
            statementsSucceeded: true,
            commit: {
                commitCallCount += 1
                return true
            },
            rollback: { rollbackCallCount += 1 }
        )

        XCTAssertTrue(commitSuccess)
        XCTAssertEqual(commitCallCount, 1)
        XCTAssertEqual(rollbackCallCount, 0)

        commitCallCount = 0
        rollbackCallCount = 0
        let statementFailure = TRXMetricsDBManager.finalizeAddressMappingTransaction(
            statementsSucceeded: false,
            commit: {
                commitCallCount += 1
                return true
            },
            rollback: { rollbackCallCount += 1 }
        )

        XCTAssertFalse(statementFailure)
        XCTAssertEqual(commitCallCount, 0)
        XCTAssertEqual(rollbackCallCount, 1)
    }

    private func makeAddressMapDefaults(testName: String) -> (UserDefaults, String) {
        let suite = "address-map.\(testName).\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defaults.removePersistentDomain(forName: suite)
        return (defaults, suite)
    }

    private func assertAddressMapDefaultsCleared(_ defaults: UserDefaults, file: StaticString = #file, line: UInt = #line) {
        XCTAssertNil(defaults.object(forKey: Metrics_Address_Map_Key), file: file, line: line)
        XCTAssertNil(defaults.object(forKey: Metrics_Address_Map_Pending_Key), file: file, line: line)
        XCTAssertNil(defaults.object(forKey: Metrics_Address_Map_Removed_Key), file: file, line: line)
    }

    func testMetricsCollectionFailsClosed() {
        let config = MetricsDataSourceStub()
        let manager = TRXStatisticalUploadManager.shared

        XCTAssertTrue(manager.isCollectionDisabled(nil))
        XCTAssertFalse(manager.isCollectionDisabled(config))

        config.isShastaEnvironment = true
        XCTAssertTrue(manager.isCollectionDisabled(config))
        config.isShastaEnvironment = false

        config.isWatchWallet = true
        XCTAssertTrue(manager.isCollectionDisabled(config))
        config.isWatchWallet = false

        config.isBasicFunctionOpen = true
        XCTAssertTrue(manager.isCollectionDisabled(config))
        config.isBasicFunctionOpen = false

        config.isTokenCloudSyncClose = true
        XCTAssertTrue(manager.isCollectionDisabled(config))
        config.isTokenCloudSyncClose = false

        config.environmentKey = ""
        XCTAssertTrue(manager.isCollectionDisabled(config))
        config.environmentKey = "MainNet"

        config.walletAddress = ""
        XCTAssertTrue(manager.isCollectionDisabled(config))
    }

    func testMetricsUploadRechecksConfigBeforeNetwork() {
        let config = MetricsDataSourceStub()
        let manager = TRXStatisticalUploadManager.shared
        manager.dataConfig = config
        defer { manager.dataConfig = nil }

        config.isTokenCloudSyncClose = true
        var failed = false
        TRXStatisticalUploadViewModel().uploadStatisticalDatabase(assets: [],
                                                                  transactions: [],
                                                                  dataConfig: config,
                                                                  chain: "MainNet",
                                                                  walletAddress: "TTestAddress",
                                                                  success: { _, _ in XCTFail("Disabled metrics must not upload") },
                                                                  failure: { failed = true })

        XCTAssertTrue(failed)
        XCTAssertEqual(config.uploadCallCount, 0)
    }

    func testMetricsUploadStopsWhenConfigIsReplaced() {
        let config = MetricsDataSourceStub()
        let manager = TRXStatisticalUploadManager.shared
        manager.dataConfig = MetricsDataSourceStub()
        defer { manager.dataConfig = nil }

        var failed = false
        TRXStatisticalUploadViewModel().uploadStatisticalDatabase(assets: [],
                                                                  transactions: [],
                                                                  dataConfig: config,
                                                                  chain: "MainNet",
                                                                  walletAddress: "TTestAddress",
                                                                  success: { _, _ in XCTFail("Replaced config must not upload") },
                                                                  failure: { failed = true })

        XCTAssertTrue(failed)
        XCTAssertEqual(config.uploadCallCount, 0)
    }

    func testMetricsReportNumberBounds() {
        let viewModel = TRXStatisticalUploadViewModel()
        let asset = TRXAssetSyncModel()
        func formatted(_ value: String) -> String {
            asset.trxBalance = value
            return String(viewModel.buildAssetParameter(from: [asset])
                .split(separator: "|", omittingEmptySubsequences: false)[3])
        }

        XCTAssertEqual(formatted(String(repeating: "9", count: 127)), "999" + String(repeating: "0", count: 124))
        XCTAssertEqual(formatted(String(repeating: "9", count: 128)), "0")
        XCTAssertEqual(formatted("-" + String(repeating: "9", count: 128)), "0")
        XCTAssertEqual(formatted("0." + String(repeating: "1", count: 129)), "0.1")
        XCTAssertEqual(formatted("0." + String(repeating: "1", count: 1_000)), "0")
        XCTAssertEqual(formatted("-1"), "-1")
    }

    func testMetricsPendingRecordsAreFilteredByWalletUid() {
        let chain = "MetricsWalletFilter-\(UUID().uuidString)"
        let date = "2000-01-01"
        let db = TRXMetricsDBManager.shared
        defer {
            for uId in ["wallet-a", "wallet-b"] {
                for asset in db.getUpdatedAssetSyncModels(forChain: chain, uId: uId) {
                    db.acknowledgeUploadedAsset(asset)
                }
                for transaction in db.getUpdatedTransactionSyncModels(forChain: chain, uId: uId) {
                    db.acknowledgeUploadedTransaction(transaction)
                }
                db.deleteAssetsBeforeToday(forChain: chain, uId: uId)
                db.deleteTransactionSyncBeforeToday(forChain: chain, uId: uId)
            }
        }

        for uId in ["wallet-a", "wallet-b"] {
            let asset = TRXAssetSyncModel()
            asset.chain = chain
            asset.uId = uId
            asset.date = date
            asset.trxBalance = "1"
            asset.usdtBalance = "1"
            asset.usdBalance = "2"
            asset.updated = true
            XCTAssertTrue(db.upsertAssetSync(model: asset))

            var transaction = TRXTransactionSyncModel()
            transaction.chain = chain
            transaction.uId = uId
            transaction.date = date
            transaction.actionType = 1
            transaction.tokenAddress = "_"
            transaction.count = 1
            transaction.updated = true
            XCTAssertTrue(db.upsertTransactionSync(model: transaction))
        }

        XCTAssertEqual(db.getUpdatedAssetSyncModels(forChain: chain, uId: "wallet-a").compactMap { $0.uId }, ["wallet-a"])
        XCTAssertEqual(db.getUpdatedTransactionSyncModels(forChain: chain, uId: "wallet-a").compactMap { $0.uId }, ["wallet-a"])
    }

    func testAddressMappingSaveOnlyDeletesMetricsOfExplicitlyRemovedIds() {
        let db = TRXMetricsDBManager.shared
        guard let originalMappings = db.loadAllAddressMappings() else {
            return XCTFail("could not read the address mapping table")
        }
        let chain = "MetricsMappingCleanup-\(UUID().uuidString)"
        let date = "2000-01-01"
        let removedAddress = "TRemoved-\(UUID().uuidString)"
        let keptAddress = "TKept-\(UUID().uuidString)"
        let removedId = UUID().uuidString
        let keptId = UUID().uuidString

        var mappings = originalMappings
        mappings[removedAddress] = removedId
        mappings[keptAddress] = keptId
        XCTAssertTrue(db.saveAddressMappings(mappings))
        defer { XCTAssertTrue(db.saveAddressMappings(originalMappings, deletingMetricsFor: [removedId, keptId])) }

        for uId in [removedId, keptId] {
            let asset = TRXAssetSyncModel()
            asset.chain = chain
            asset.uId = uId
            asset.date = date
            asset.updated = true
            XCTAssertTrue(db.upsertAssetSync(model: asset))

            var transaction = TRXTransactionSyncModel()
            transaction.chain = chain
            transaction.uId = uId
            transaction.date = date
            transaction.actionType = 1
            transaction.tokenAddress = "_"
            transaction.updated = true
            XCTAssertTrue(db.upsertTransactionSync(model: transaction))
        }

        // Writing a mapping that happens to omit both IDs must not touch their metrics:
        // that is what an incomplete in-memory map looks like after a failed load.
        XCTAssertTrue(db.saveAddressMappings(originalMappings))
        XCTAssertFalse(db.getUpdatedAssetSyncModels(forChain: chain, uId: removedId).isEmpty)
        XCTAssertFalse(db.getUpdatedTransactionSyncModels(forChain: chain, uId: removedId).isEmpty)
        XCTAssertFalse(db.getUpdatedAssetSyncModels(forChain: chain, uId: keptId).isEmpty)

        mappings.removeValue(forKey: removedAddress)
        XCTAssertTrue(db.saveAddressMappings(mappings, deletingMetricsFor: [removedId]))
        XCTAssertTrue(db.getUpdatedAssetSyncModels(forChain: chain, uId: removedId).isEmpty)
        XCTAssertTrue(db.getUpdatedTransactionSyncModels(forChain: chain, uId: removedId).isEmpty)
        XCTAssertFalse(db.getUpdatedAssetSyncModels(forChain: chain, uId: keptId).isEmpty)
        XCTAssertFalse(db.getUpdatedTransactionSyncModels(forChain: chain, uId: keptId).isEmpty)
    }

    func testMetricsAssetUpdatesWhenOnlyUsdBalanceChanges() {
        let config = MetricsDataSourceStub()
        let manager = TRXStatisticalUploadManager.shared
        manager.dataConfig = config
        defer { manager.dataConfig = nil }

        let chain = "MetricsUsdUpdate-\(UUID().uuidString)"
        let uId = "wallet"
        let date = "2000-01-01"
        defer {
            if let asset = TRXMetricsDBManager.shared.getAssetSyncModel(chain: chain, uId: uId, date: date) {
                TRXMetricsDBManager.shared.acknowledgeUploadedAsset(asset)
            }
            TRXMetricsDBManager.shared.deleteAssetsBeforeToday(forChain: chain, uId: uId)
        }
        let original = TRXAssetSyncModel()
        original.chain = chain
        original.uId = uId
        original.date = date
        original.trxBalance = "1"
        original.usdtBalance = "1"
        original.usdBalance = "2"
        original.updated = false
        XCTAssertTrue(TRXMetricsDBManager.shared.upsertAssetSync(model: original))

        let changed = TRXAssetSyncModel()
        changed.chain = chain
        changed.uId = uId
        changed.date = date
        changed.trxBalance = "1"
        changed.usdtBalance = "1"
        changed.usdBalance = "3"
        manager.upsertAssetData(model: changed)

        let stored = TRXMetricsDBManager.shared.getAssetSyncModel(chain: chain, uId: uId, date: date)
        XCTAssertEqual(stored?.usdBalance, "3")
        XCTAssertEqual(stored?.updated, true)
    }

    func testMetricsAcknowledgementPreservesNewerData() {
        let chain = "MetricsAcknowledgement-\(UUID().uuidString)"
        let uId = "wallet"
        let date = "2000-01-01"
        let db = TRXMetricsDBManager.shared
        defer {
            if let asset = db.getAssetSyncModel(chain: chain, uId: uId, date: date) {
                db.acknowledgeUploadedAsset(asset)
            }
            if let transaction = db.getTransactionSyncModel(chain: chain, uId: uId, actionType: 1, tokenAddress: "_", date: date) {
                db.acknowledgeUploadedTransaction(transaction)
            }
            db.deleteAssetsBeforeToday(forChain: chain, uId: uId)
            db.deleteTransactionSyncBeforeToday(forChain: chain, uId: uId)
        }

        let asset = TRXAssetSyncModel()
        asset.chain = chain
        asset.uId = uId
        asset.date = date
        asset.trxBalance = "1"
        asset.usdtBalance = "1"
        asset.usdBalance = "2"
        asset.updated = true
        XCTAssertTrue(db.upsertAssetSync(model: asset))

        var transaction = TRXTransactionSyncModel()
        transaction.chain = chain
        transaction.uId = uId
        transaction.date = date
        transaction.actionType = 1
        transaction.tokenAddress = "_"
        transaction.count = 1
        transaction.tokenAmount = "1"
        transaction.updated = true
        XCTAssertTrue(db.upsertTransactionSync(model: transaction))

        guard let uploadedAsset = db.getUpdatedAssetSyncModels(forChain: chain, uId: uId).first,
              let uploadedTransaction = db.getUpdatedTransactionSyncModels(forChain: chain, uId: uId).first else {
            return XCTFail("Missing upload snapshots")
        }

        asset.usdBalance = "3"
        XCTAssertTrue(db.upsertAssetSync(model: asset))
        transaction.count = 2
        transaction.tokenAmount = "2"
        XCTAssertTrue(db.upsertTransactionSync(model: transaction))

        XCTAssertFalse(db.acknowledgeUploadedAsset(uploadedAsset))
        XCTAssertFalse(db.acknowledgeUploadedTransaction(uploadedTransaction))
        XCTAssertEqual(db.getAssetSyncModel(chain: chain, uId: uId, date: date)?.updated, true)
        XCTAssertEqual(db.getTransactionSyncModel(chain: chain, uId: uId, actionType: 1, tokenAddress: "_", date: date)?.updated, true)

        guard let currentAsset = db.getAssetSyncModel(chain: chain, uId: uId, date: date),
              let currentTransaction = db.getTransactionSyncModel(chain: chain, uId: uId, actionType: 1, tokenAddress: "_", date: date) else {
            return XCTFail("Missing current records")
        }
        XCTAssertTrue(db.acknowledgeUploadedAsset(currentAsset))
        XCTAssertTrue(db.acknowledgeUploadedTransaction(currentTransaction))
        XCTAssertEqual(db.getAssetSyncModel(chain: chain, uId: uId, date: date)?.updated, false)
        XCTAssertEqual(db.getTransactionSyncModel(chain: chain, uId: uId, actionType: 1, tokenAddress: "_", date: date)?.updated, false)
    }

    func testMetricsParameterEncryptionFailsClosed() {
        let manager = TRXStatisticalUploadManager.shared
        let signature = String(repeating: "a", count: 40)
        let request = "https://example.com/upload?signature=\(signature)"
        let base64Signature = "+/" + String(repeating: "A", count: 25) + "="
        let base64Request = "https://example.com/upload?signature=\(base64Signature.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!)"

        XCTAssertTrue(manager.parameterProcessing(parameters: ["X": "plain"],
                                                  requestString: "https://example.com/upload",
                                                  headers: ["ts": "1712345678901"]).isEmpty)
        XCTAssertTrue(manager.parameterProcessing(parameters: ["X": "plain"],
                                                  requestString: request,
                                                  headers: [:]).isEmpty)
        XCTAssertTrue(manager.parameterProcessing(parameters: ["X": "plain"],
                                                  requestString: "https://example.com/upload?signature=invalid!",
                                                  headers: ["ts": "1712345678901"]).isEmpty)
        XCTAssertTrue(manager.parameterProcessing(parameters: ["X": "plain"],
                                                  requestString: request,
                                                  headers: ["ts": "171234567890x"]).isEmpty)
        XCTAssertEqual(manager.parameterProcessing(parameters: ["X": "plain"],
                                                   requestString: base64Request,
                                                   headers: ["ts": "1712345678"]).count,
                       1)
        XCTAssertEqual(manager.parameterProcessing(parameters: ["X": "plain"],
                                                   requestString: request,
                                                   headers: ["ts": "1712345678901"]).count,
                       1)
    }

    func testBase58CheckRoundTripWithFlickrAlphabet() {
        let payload = Data([0x00, 0x41, 0x88, 0xff, 0x10, 0x7c, 0x23, 0x5a])
        let encoded = String(base58CheckEncoding: payload, alphabet: Base58String.flickrAlphabet)
        let decoded = Data(base58CheckDecoding: encoded, alphabet: Base58String.flickrAlphabet)

        XCTAssertNotEqual(encoded, String(base58CheckEncoding: payload))
        XCTAssertEqual(decoded, payload)
    }

    func testStrictHexAddressConversionRejectsGarbage() {
        var payload = Data([0x41])
        payload.append(contentsOf: Array(repeating: UInt8(0x11), count: 20))
        let hex = payload.map { String(format: "%02x", $0) }.joined()

        let valid = hex.convertBase58HexAddressToTronAddress()
        XCTAssertFalse(valid.isEmpty)
        XCTAssertTrue(valid.isTRXAddress())
        XCTAssertTrue(valid.isEIP712TronAddress())
        XCTAssertEqual(valid.convertTronAddressToBase58HexAddress().lowercased(), hex)

        XCTAssertEqual("".convertBase58HexAddressToTronAddress(), "")
        XCTAssertEqual("41".convertBase58HexAddressToTronAddress(), "")
        XCTAssertEqual("41ZZ\(String(hex.dropFirst(2)))".convertBase58HexAddressToTronAddress(), "")
        XCTAssertNil("abZZ".hexDecodedData())
        XCTAssertNil("abc".hexDecodedData())
        XCTAssertFalse("41notanaddress".isEIP712TronAddress())
        XCTAssertFalse("Tnotanaddress".isEIP712TronAddress())
    }

    func testHexValidationRejectsTrailingLineTerminators() {
        // ICU lets `$` match before a final line terminator, so `^...$` accepted these.
        XCTAssertFalse("ABCDEF\r\n".isSignStringHexEncoded)
        XCTAssertFalse("0xABCDEF\r\n".isSignStringHexEncoded)
        XCTAssertFalse("0xABCDEF\n".isHexEncoded)
        XCTAssertFalse("0xABCDEF\r\n".isHexEncoded)
        XCTAssertFalse("0xABCDEF\u{2028}".isHexEncoded)

        XCTAssertTrue("ABCDEF".isSignStringHexEncoded)
        XCTAssertTrue("0xABCDEF".isSignStringHexEncoded)
        XCTAssertTrue("0xABCDEF".isHexEncoded)

        // Rejected input must be UTF-8 encoded, not passed through as if it were hex.
        XCTAssertEqual(try "ABCDEF\r\n".signStringHexEncoded(), "4142434445460d0a")
        XCTAssertEqual(try "ABCDEF".signStringHexEncoded(), "ABCDEF")
        XCTAssertThrowsError(try "0xABCDEF\r\n".signStringHexEncoded())
    }

    func testBase58RejectsInvalidAlphabets() {
        let payload = Data([0x00, 0x41])
        let invalidAlphabets = [
            [UInt8](),
            [UInt8](repeating: 0x31, count: 1),
            [UInt8](repeating: 0x31, count: 58),
            Array(Base58String.btcAlphabet.dropLast()) + [0x80]
        ]

        XCTAssertNotNil(String(base58Encoding: payload, validatingAlphabet: Base58String.flickrAlphabet))
        XCTAssertNotNil(String(base58CheckEncoding: payload, validatingAlphabet: Base58String.flickrAlphabet))

        for alphabet in invalidAlphabets {
            XCTAssertNil(String(base58Encoding: payload, validatingAlphabet: alphabet))
            XCTAssertNil(String(base58CheckEncoding: payload, validatingAlphabet: alphabet))
            XCTAssertNil(Data(base58Decoding: "1", alphabet: alphabet))
            XCTAssertNil(Data(base58CheckDecoding: "1", alphabet: alphabet))
        }
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure() {
            // Put the code you want to measure the time of here.
        }
    }
    
    // create new wallet
    func testCreateWallet() {
        let exp = expectation(description: "testCreateWallet")
        TLWalletCore.createWalletAccount(keyStore: self.keyStore, password: self.password) {  result in
            switch result {
            case .success(let account):
                let walletAddress = String(base58CheckEncoding: account.address.data)
                print("createWallet: \(walletAddress)")
                XCTAssert(true)
                break
            case .failure(let error):
                print(error)
                XCTAssert(false)
                break
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 60)
    }
    
    // Sign Transaction
    func testSignTransaction() {
        let exp = expectation(description: "testSignTransaction")
        TLWalletCore.createWalletAccount(keyStore: self.keyStore, password: self.password) {  result in
            switch result {
            case .success(let account):
                let walletAddress = String(base58CheckEncoding: account.address.data)
                print("createWallet: \(walletAddress)")
                XCTAssert(walletAddress.count > 0)

                let newContract: TransferContract = TransferContract()
                newContract.ownerAddress = walletAddress.base58CheckData
                newContract.toAddress = walletAddress.base58CheckData
                newContract.amount = 1

                self.tWallet.getNowBlock2(withRequest: EmptyMessage()) { blockExtention, error in
                    if blockExtention == nil || error != nil {
                        XCTAssert(false)
                    }
                    
                    let transaction = TronTransaction()
                    let rawData: Transaction_raw = Transaction_raw()
                    rawData.refBlockHash = blockExtention?.blockid.subdata(in: Range(NSRange(location: 8, length: 8))!)
                    
                    var result = Data()
                    let uint8Convert = Data([UInt8(truncatingIfNeeded: (blockExtention?.blockHeader.rawData.number ?? 0) >> 8),UInt8(truncatingIfNeeded: (blockExtention?.blockHeader.rawData.number ?? 0))])
                    result.append(uint8Convert)
                    rawData.refBlockBytes = result
                    
                    let transactionContract: Transaction_Contract = Transaction_Contract()
                    transactionContract.type = .transferContract
                    transactionContract.parameter.typeURL = "type.googleapis.com/protocol." + "TransferContract"
                    transactionContract.parameter.value = newContract.data() ?? Data()
                    rawData.contractArray = [transactionContract]
                    transaction.rawData = rawData
                    
                    let data = transaction.rawData.data() ?? Data()
                    let signResult = TLWalletCore.signTranscation(keyStore: self.keyStore, transaction: data, password: self.password, address: walletAddress)
                            
                    switch signResult {
                    case .success(let data):
                        print(data)
                        exp.fulfill()
                        XCTAssert(true)
                        break
                    case .failure(let error):
                        print(error)
                        exp.fulfill()
                        XCTAssert(false)
                        break
                    }
                }
                break
            case .failure(let error):
                print(error)
                exp.fulfill()
                XCTAssert(false)
                break
            }
        }
        wait(for: [exp], timeout: 60)
    }

    func testSignTransactionAddsOneSignaturePerSigner() throws {
        let firstAccount = try keyStore.createAccount(password: password, type: .hierarchicalDeterministicWallet)
        let secondAccount = try keyStore.createAccount(password: password, type: .hierarchicalDeterministicWallet)
        let transaction = TronTransaction()
        let rawData = Transaction_raw()
        rawData.contractArray = [Transaction_Contract(), Transaction_Contract()]
        transaction.rawData = rawData

        let firstAddress = String(base58CheckEncoding: firstAccount.address.data)
        guard case .success = TLWalletCore.signTranscation(keyStore: keyStore, transaction: transaction, password: password, address: firstAddress) else {
            return XCTFail("First signer failed")
        }
        XCTAssertEqual(transaction.signatureArray.count, 1)

        transaction.signatureArray.add(transaction.signatureArray[0])
        XCTAssertEqual(transaction.signatureArray.count, 2)

        let secondAddress = String(base58CheckEncoding: secondAccount.address.data)
        guard case .success = TLWalletCore.signTranscation(keyStore: keyStore, transaction: transaction, password: password, address: secondAddress) else {
            return XCTFail("Second signer failed")
        }
        XCTAssertEqual(transaction.signatureArray.count, 2)

        guard case .success = TLWalletCore.signTranscation(keyStore: keyStore, transaction: transaction, password: password, address: firstAddress) else {
            return XCTFail("Repeated signer failed")
        }
        XCTAssertEqual(transaction.signatureArray.count, 2)
    }

    func testSignTransactionRejectsTooManySignatures() throws {
        let account = try keyStore.createAccount(password: password, type: .hierarchicalDeterministicWallet)
        let transaction = TronTransaction()
        let rawData = Transaction_raw()
        rawData.contractArray = [Transaction_Contract()]
        transaction.rawData = rawData
        (0..<5).forEach { _ in transaction.signatureArray.add(Data(repeating: 0, count: 65)) }

        let address = String(base58CheckEncoding: account.address.data)
        guard case .failure(.failedToSignTransaction) = TLWalletCore.signTranscation(keyStore: keyStore, transaction: transaction, password: password, address: address) else {
            return XCTFail("A sixth signature should not be added")
        }
        XCTAssertEqual(transaction.signatureArray.count, 5)

        transaction.signatureArray.add(Data(repeating: 0, count: 65))
        guard case .failure(.failedToSignTransaction) = TLWalletCore.signTranscation(keyStore: keyStore, transaction: transaction, password: password, address: address) else {
            return XCTFail("Too many signatures should be rejected")
        }
        XCTAssertEqual(transaction.signatureArray.count, 6)
    }
    
    // Sign String
    func testSignMessage() {
        let exp = expectation(description: "testSignMessage")
        TLWalletCore.createWalletAccount(keyStore: self.keyStore, password: self.password) {  result in
            switch result {
            case .success(let account):
                let walletAddress = String(base58CheckEncoding: account.address.data)
                print("createWallet: \(walletAddress)")
                XCTAssert(walletAddress.count > 0)

                let unSignedString = "abcd"
                // sign v1
                let result1 = TLWalletCore.signString(keyStore: self.keyStore, unSignedString: unSignedString, password: self.password, address: walletAddress)
                print("sign v1: \(result1)")
                switch result1 {
                case .success(let signature):
                    XCTAssert(signature.count > 0)
                case .failure(let error):
                    XCTFail("sign v1 failed: \(error.localizedDescription)")
                }
                
                // sign v2
                let messageSignV2: TLMessageSignV2Type = .string
                let result2 = TLWalletCore.signStringV2(keyStore: self.keyStore, unSignedString: unSignedString, password: self.password, address: walletAddress, messageSignV2)
                print("sign v2: \(result2)")
                switch result2 {
                case .success(let signature):
                    XCTAssert(signature.count > 0)
                case .failure(let error):
                    XCTFail("sign v2 failed: \(error.localizedDescription)")
                }

                break
            case .failure(let error):
                print(error)
                XCTAssert(false)
                break
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 60)
    }
    
    // Export PrivateKey
    func testExportPrivateKey() {
        let exp = expectation(description: "testExportPrivateKey")
        TLWalletCore.createWalletAccount(keyStore: self.keyStore, password: self.password) {  result in
            switch result {
            case .success(let account):
                let walletAddress = String(base58CheckEncoding: account.address.data)
                print("createWallet: \(walletAddress)")
                XCTAssert(walletAddress.count > 0)
                
                let result = TLWalletCore.walletExportPrivateKey(keyStore: self.keyStore, password: self.password, address: walletAddress)
                switch result {
                case .success(let privateKey):
                    XCTAssert(privateKey.count > 0)
                case .failure(let error):
                    XCTFail("export private key failed: \(error.localizedDescription)")
                }

                break
            case .failure(let error):
                print(error)
                XCTAssert(false)
                break
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 60)
    }

    // Export Mnemonic
    func testExportMnemonic() {
        let exp = expectation(description: "testExportMnemonic")
        TLWalletCore.createWalletAccount(keyStore: self.keyStore, password: self.password) {  result in
            switch result {
            case .success(let account):
                let walletAddress = String(base58CheckEncoding: account.address.data)
                print("createWallet: \(walletAddress)")
                XCTAssert(walletAddress.count > 0)
                
                let result = TLWalletCore.walletExportMnemonic(keyStore: self.keyStore, password: self.password, address: walletAddress)
                switch result {
                case .success(let mnemonic):
                    XCTAssert(mnemonic.count > 0)
                case .failure(let error):
                    XCTFail("export mnemonic failed: \(error.localizedDescription)")
                }

                break
            case .failure(let error):
                print(error)
                XCTAssert(false)
                break
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 60)
    }

}

private final class MetricsDataSourceStub: TRXMetricsDataSource {
    var environmentKey = "MainNet"
    var isShastaEnvironment = false
    var isWatchWallet = false
    var isBasicFunctionOpen = false
    var isTokenCloudSyncClose = false
    var walletAddress = "TTestAddress"
    var uploadWalletType = 0
    var usdtContractAddress = "TUSDT"
    var isOnlineEnvironment = true
    var isPreReleaseEnvironment = false
    private(set) var uploadCallCount = 0

    func uploadStatisticalData(parameters: [String: Any], visible: Bool, success: @escaping (Bool, Bool) -> Void,
                               failure: @escaping () -> Void) {
        uploadCallCount += 1
    }
}
