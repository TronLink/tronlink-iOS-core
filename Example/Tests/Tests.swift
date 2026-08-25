import XCTest
@testable import TLCore

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

    func testMetricsAssetUpdatesWhenUsdBalanceRecoversFromEmpty() {
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
        original.usdBalance = ""
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

import BigInt
import CryptoSwift

final class EmbeddedWeb3GoldenTests: XCTestCase {
    private let privateKeyData = Data(repeating: 0, count: 31) + Data([1])
    private let messageHash = Data(repeating: 0x11, count: 32)

    func testPrivateKeySignAndRecoverMatchesGoldenValues() throws {
        let key = TLCore.PrivateKey(privateKeyData)
        try key.verify()
        XCTAssertEqual(key.publicKey.hex,
                       "0479be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798483ada7726a3c4655da4fbfc0e1108a8fd17b448a68554199c47d08ffb10d4b8")
        XCTAssertEqual(key.address.address, "0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf")
        let signature = try key.sign(hash: messageHash)
        try signature.check()
        XCTAssertEqual(signature.data.count, 65)
        XCTAssertLessThan(signature.v, 4)
        XCTAssertEqual(signature.r.serialize().count, 32)
        XCTAssertLessThanOrEqual(signature.s.serialize().count, 32)
        XCTAssertEqual(try TLCore.Web3Utils.hashECRecover(hash: messageHash, signature: signature.data), key.address)
        XCTAssertEqual(try TLCore.Web3Utils.getAddressFromSignature(messageHash, signature: signature.data.hex), key.address)
    }

    func testABIv2EncodingAndDecodingMatchesGoldenValues() throws {
        XCTAssertThrowsError(try TLCore.ABIv2TypeParser.parseTypeString("(address,uint256[])[]"))
        let embeddedType = try TLCore.ABIv2TypeParser.parseTypeString("uint256[][2]")
        guard case let .array(type: embeddedInner, length: embeddedOuterLength) = embeddedType,
              case let .array(type: embeddedLeaf, length: embeddedInnerLength) = embeddedInner,
              case let .uint(bits: embeddedBits) = embeddedLeaf else {
            return XCTFail("Embedded parser did not produce the expected nested array structure")
        }
        XCTAssertEqual(embeddedOuterLength, 2)
        XCTAssertEqual(embeddedInnerLength, 0)
        XCTAssertEqual(embeddedBits, 256)

        let encoded = try XCTUnwrap(TLCore.ABIv2Encoder.encode(
            types: [.uint(bits: 256)],
            values: [BigUInt(42) as AnyObject]
        ))
        XCTAssertEqual(encoded.hex, String(repeating: "0", count: 62) + "2a")
        let decoded = try XCTUnwrap(TLCore.ABIv2Decoder.decode(types: [.uint(bits: 256)], data: encoded))
        XCTAssertEqual(decoded.first as? BigUInt, BigUInt(42))
    }

    func testMergedHexHelpersPreserveBothRequiredBehaviors() throws {
        XCTAssertEqual(Data([0x00, 0xff]).hex, "00ff")
        XCTAssertEqual("TRON".hex, "54524f4e")
        XCTAssertEqual(Data.fromHex("0xabc"), Data([0xab, 0x0c]))
        XCTAssertThrowsError(try "0x".dataFromHex())
    }

    func testEventLogDecodesApprovedCompatibilityFields() throws {
        let json = """
        {
          "address": "0x53066cddbc0099eb6c96785d9b3df2aaeede5da3",
          "blockHash": "0x779c1f08f2b5252873f08fd6ec62d75bb54f956633bbb59d33bd7c49f1a3d389",
          "blockNumber": "0x4f58f8",
          "data": "0x0000000000000000000000000000000000000000000000004563918244f40000",
          "logIndex": "0x84",
          "removed": "0x0",
          "topics": [
            "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
            "0x000000000000000000000000efdcf2c36f3756ce7247628afdb632fa4ee12ec5",
            "0x000000000000000000000000d5395c132c791a7f46fa8fc27f0ab6bacd824484"
          ],
          "transactionHash": "0x9f7bb2633abb3192d35f65e50a96f9f7ca878fa2ee7bf5d3fca489c0c60dc79a",
          "transactionIndex": "0x99"
        }
        """
        let log = try JSONDecoder().decode(TLCore.EventLog.self, from: try XCTUnwrap(json.data(using: .utf8)))
        XCTAssertEqual(log.address.addressData.count, 20)
        XCTAssertEqual(log.blockNumber, BigUInt(0x4f58f8))
        XCTAssertEqual(log.logIndex, BigUInt(0x84))
        XCTAssertGreaterThanOrEqual(log.topics.count, 2)
        XCTAssertTrue(log.topics.allSatisfy { $0.count == 32 })
    }

    func testPrivateKeyRejectsOutOfRangeRandomScalar() {
        var valid = Data(repeating: 0, count: 32)
        valid[31] = 1
        var candidates = [Data(repeating: 0xff, count: 32), valid]

        let generated = TLCore.PrivateKey.generatePrivateKey { candidates.removeFirst() }

        XCTAssertEqual(generated, valid)
        XCTAssertTrue(candidates.isEmpty)
    }
}

final class EmbeddedABIGoldenTests: XCTestCase {
    func testEmbeddedAddressAndIntegerEncodingMatchGoldenValues() throws {
        let bytes = Data([0x7e, 0x5f, 0x45, 0x52, 0x09, 0x1a, 0x69, 0x12, 0x5d, 0x5d,
                          0xfc, 0xb7, 0xb8, 0xc2, 0x65, 0x90, 0x29, 0x39, 0x5b, 0xdf])
        let address = TLCore.Address(data: bytes)
        XCTAssertEqual(address.eip55String, "0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf")
        let encoder = TLCore.ABIEncoder()
        try encoder.encode(BigUInt(42))
        XCTAssertEqual(encoder.data.hexString, String(repeating: "0", count: 62) + "2a")
    }

    func testEmbeddedFunctionDynamicValuesAndRLPMatchGoldenValues() throws {
        let function = TLCore.Function(
            name: "submit",
            parameters: [.address, .uint(bits: 256), .bool, .string, .dynamicArray(.uint(bits: 256))]
        )
        XCTAssertEqual(function.description, "submit(address,uint256,bool,string,uint256[])")
        XCTAssertEqual(TLCore.RLP.encode([Data([0x01]), Data([0x02, 0x03])] as [Any]),
                       Data([0xc4, 0x01, 0x82, 0x02, 0x03]))
    }

    func testEmbeddedTronDerivationAndBase58MatchGoldenValues() throws {
        let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
        let key = try TLCore.Wallet(mnemonic: mnemonic).getKey(at: 0)
        XCTAssertEqual(key.privateKey.hexString,
                       "b5a4cea271ff424d7c31dc12a3e43e401df7a40d7412a15750f3f0b6b5449a28")
        XCTAssertEqual(key.address.data.count, 20)
        let keystoreKey = try TLCore.KeystoreKey(
            password: "baseline-password",
            mnemonic: mnemonic
        )
        XCTAssertEqual(keystoreKey.address.data.count, 21)
        XCTAssertEqual(keystoreKey.address.data.first, 0x41)
        XCTAssertEqual(Data(keystoreKey.address.data.dropFirst()), key.address.data)
        let zeroAddress = "T9yD14Nj9j7xAB4dbGeiX9h8unkKHxuWwb"
        XCTAssertEqual(zeroAddress.base58CheckData?.hexString,
                       "410000000000000000000000000000000000000000")
    }

    func testProtobufAddressRetainsBehaviorUnderSwiftRename() {
        let proto = TronProtoAddress()
        proto.host = Data([127, 0, 0, 1])
        proto.port = 18888
        XCTAssertEqual(proto.host, Data([127, 0, 0, 1]))
        XCTAssertEqual(proto.port, 18888)
    }
}
final class EmbeddedKeystoreTests: XCTestCase {
    /// BIP39 test vector.
    private let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
    private let password = "keystore-password"

    private var keyDirectory: URL!
    private var shouldRemoveKeyDirectory = true

    override func setUp() {
        super.setUp()
        keyDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        shouldRemoveKeyDirectory = true
    }

    override func tearDown() {
        if shouldRemoveKeyDirectory {
            try? FileManager.default.removeItem(at: keyDirectory)
        }
        super.tearDown()
    }

    /// The passphrase is a BIP39 derivation input, so losing it across a restart silently
    /// re-derives a different private key for the same address.
    func testPassphraseSurvivesReload() throws {
        let passphrase = "correct horse battery staple"

        let store = try KeyStore(keyDirectory: keyDirectory)
        _ = try store.import(mnemonic: mnemonic, passphrase: passphrase, encryptPassword: password)

        let reloaded = try KeyStore(keyDirectory: keyDirectory)
        let account = try XCTUnwrap(reloaded.accounts.first)
        let exported = try reloaded.exportPrivateKey(account: account, password: password)

        let expected = try Wallet(mnemonic: mnemonic, passphrase: passphrase).getKey(at: 0).privateKey
        XCTAssertEqual(exported, expected)
    }

    /// An empty passphrase must keep producing the pre-existing payload layout, otherwise keys
    /// written by earlier versions no longer decode.
    func testKeyWithoutPassphraseSurvivesReload() throws {
        let store = try KeyStore(keyDirectory: keyDirectory)
        _ = try store.import(mnemonic: mnemonic, encryptPassword: password)

        let reloaded = try KeyStore(keyDirectory: keyDirectory)
        let account = try XCTUnwrap(reloaded.accounts.first)
        XCTAssertEqual(try reloaded.exportMnemonic(account: account, password: password), mnemonic)

        let expected = try Wallet(mnemonic: mnemonic).getKey(at: 0).privateKey
        XCTAssertEqual(try reloaded.exportPrivateKey(account: account, password: password), expected)
    }

    /// Guards the round trip against a payload split that would hand the passphrase bytes back
    /// as part of the mnemonic.
    func testExportedMnemonicExcludesPassphrase() throws {
        let store = try KeyStore(keyDirectory: keyDirectory)
        let account = try store.import(mnemonic: mnemonic, passphrase: "p@ss", encryptPassword: password)
        XCTAssertEqual(try store.exportMnemonic(account: account, password: password), mnemonic)
    }

    func testHDObjectsDoNotRetainMnemonicOrPassphrase() throws {
        let passphrase = "p@ss"
        let wallet = try Wallet(mnemonic: mnemonic, passphrase: passphrase)
        let walletFields = Mirror(reflecting: wallet).children.compactMap { $0.label }
        let walletStrings = Mirror(reflecting: wallet).children.compactMap { $0.value as? String }
        XCTAssertFalse(walletFields.contains("mnemonic"))
        XCTAssertFalse(walletFields.contains("passphrase"))
        XCTAssertFalse(walletStrings.contains(mnemonic))
        XCTAssertFalse(walletStrings.contains(passphrase))

        let key = try KeystoreKey(password: password, mnemonic: mnemonic, passphrase: passphrase)
        let keyFields = Mirror(reflecting: key).children.compactMap { $0.label }
        let keyStrings = Mirror(reflecting: key).children.compactMap { $0.value as? String }
        XCTAssertFalse(keyFields.contains("mnemonic"))
        XCTAssertFalse(keyFields.contains("passphrase"))
        XCTAssertFalse(keyStrings.contains(mnemonic))
        XCTAssertFalse(keyStrings.contains(passphrase))

        let store = try KeyStore(keyDirectory: keyDirectory)
        let account = try store.import(mnemonic: mnemonic, passphrase: passphrase, encryptPassword: password)
        let cachedKey = try XCTUnwrap(store.key(for: account.address))
        let cachedStrings = Mirror(reflecting: cachedKey).children.compactMap { $0.value as? String }
        XCTAssertFalse(cachedStrings.contains(mnemonic))
        XCTAssertFalse(cachedStrings.contains(passphrase))

        wallet.clear()
        XCTAssertThrowsError(try wallet.getKey(at: 0)) { error in
            guard case Wallet.Error.cleared = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertEqual(try store.exportMnemonic(account: account, password: password), mnemonic)
    }

    func testGeneratedHDWalletReturnsMnemonicWithoutRetainingIt() throws {
        let generated = try KeystoreKey.generateHDWallet(password: password)
        XCTAssertTrue(Mnemonic.isValid(generated.mnemonic))
        XCTAssertEqual(try KeystoreKey(password: password, mnemonic: generated.mnemonic).address,
                       generated.key.address)
        XCTAssertFalse(Mirror(reflecting: generated.key).children.compactMap { $0.label }.contains("mnemonic"))

        let store = try KeyStore(keyDirectory: keyDirectory)
        let account = try store.createAccount(password: password, type: .hierarchicalDeterministicWallet)
        XCTAssertTrue(Mnemonic.isValid(try store.exportMnemonic(account: account, password: password)))
    }

    func testDeleteRequiresCorrectPassword() throws {
        let store = try KeyStore(keyDirectory: keyDirectory)
        let account = try store.import(mnemonic: mnemonic, encryptPassword: password)

        XCTAssertThrowsError(try store.delete(account: account, password: "wrong-password")) { error in
            guard case DecryptError.invalidPassword = error else {
                return XCTFail("Expected invalidPassword, got \(error)")
            }
        }
        XCTAssertNotNil(store.account(for: account.address))
        XCTAssertNotNil(store.key(for: account.address))
        XCTAssertTrue(FileManager.default.fileExists(atPath: account.url.path))

        let unrelatedURL = keyDirectory.appendingPathComponent("unrelated")
        try Data().write(to: unrelatedURL)
        var suppliedAccount = account
        suppliedAccount.url = unrelatedURL

        try store.delete(account: suppliedAccount, password: password)
        XCTAssertNil(store.account(for: account.address))
        XCTAssertNil(store.key(for: account.address))
        XCTAssertFalse(FileManager.default.fileExists(atPath: account.url.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: unrelatedURL.path))
    }

    func testDifferentPassphrasesDeriveDifferentKeys() throws {
        let a = try Wallet(mnemonic: mnemonic, passphrase: "one").getKey(at: 0).privateKey
        let b = try Wallet(mnemonic: mnemonic, passphrase: "two").getKey(at: 0).privateKey
        XCTAssertNotEqual(a, b)
    }

    /// The C layer bounds the passphrase in bytes. Checking `String.count` let a multi-byte
    /// passphrase past the guard and turned the derivation failure into a trap.
    func testOverlongMultiBytePassphraseThrows() {
        let passphrase = String(repeating: "🔑", count: 65) // 65 characters, 260 UTF-8 bytes
        XCTAssertEqual(passphrase.count, 65)
        XCTAssertEqual(passphrase.utf8.count, 260)
        XCTAssertThrowsError(try Mnemonic.deriveSeed(mnemonic: mnemonic, passphrase: passphrase))
    }

    /// A 256-byte passphrase is exactly at the limit and must still derive.
    func testPassphraseAtByteLimitDerives() throws {
        let passphrase = String(repeating: "a", count: 256)
        XCTAssertEqual(try Mnemonic.deriveSeed(mnemonic: mnemonic, passphrase: passphrase).count, 64)
    }

    /// `EthereumCrypto` reports an invalid private key by returning an empty `Data`, since its
    /// return type is `nonnull`. Decoding an address from that used to trap, including in release
    /// builds, rather than surfacing an error.
    func testInvalidPrivateKeyThrowsInsteadOfTrapping() {
        XCTAssertThrowsError(try KeystoreKey(password: password, key: Data(repeating: 1, count: 16)))
        XCTAssertThrowsError(try KeystoreKey(password: password, key: Data(repeating: 0, count: 32)))
    }

    /// `import(json:)` used to send every decrypted payload through the raw-key path. For an HD
    /// keystore that made the private key the first 32 characters of the mnemonic.
    func testHDKeystoreJSONRoundTripPreservesAddress() throws {
        let store = try KeyStore(keyDirectory: keyDirectory)
        let account = try store.import(mnemonic: mnemonic, passphrase: "p@ss", encryptPassword: password)
        let json = try store.export(account: account, password: password, newPassword: password)

        let target = try KeyStore(keyDirectory: keyDirectory.appendingPathComponent("imported"))
        let imported = try target.import(json: json, password: password, newPassword: password)

        XCTAssertEqual(imported.address, account.address)
        XCTAssertEqual(imported.type, .hierarchicalDeterministicWallet)
        XCTAssertEqual(try target.exportMnemonic(account: imported, password: password), mnemonic)
        XCTAssertEqual(try target.exportPrivateKey(account: imported, password: password),
                       try store.exportPrivateKey(account: account, password: password))
    }

    func testUpdatePasswordPreservesCustomDerivationPathAndRejectsAddressChange() throws {
        let customPath = "m/44'/195'/7'/0/3"
        let importingStore = try KeyStore(keyDirectory: keyDirectory)
        let account = try importingStore.import(mnemonic: mnemonic, derivationPath: customPath, encryptPassword: password)
        let privateKey = try importingStore.exportPrivateKey(account: account, password: password)

        let store = try KeyStore(keyDirectory: keyDirectory)
        let storedAccount = try XCTUnwrap(store.account(for: account.address))

        XCTAssertThrowsError(try store.update(account: storedAccount,
                                              password: password,
                                              newPassword: "wrong-path-password",
                                              derivationPath: Wallet.defaultPath)) { error in
            guard case KeyStore.Error.invalidKey = error else {
                return XCTFail("expected invalidKey, got \(error)")
            }
        }

        let unchangedStore = try KeyStore(keyDirectory: keyDirectory)
        let unchangedAccount = try XCTUnwrap(unchangedStore.account(for: account.address))
        XCTAssertEqual(try unchangedStore.generateWalletPath(account: unchangedAccount), customPath)
        XCTAssertEqual(try unchangedStore.exportPrivateKey(account: unchangedAccount, password: password), privateKey)

        let updatedPassword = "updated-keystore-password"
        try unchangedStore.update(account: unchangedAccount, password: password, newPassword: updatedPassword)

        let reloaded = try KeyStore(keyDirectory: keyDirectory)
        let reloadedAccount = try XCTUnwrap(reloaded.account(for: account.address))
        XCTAssertEqual(try reloaded.generateWalletPath(account: reloadedAccount), customPath)
        XCTAssertEqual(try reloaded.exportPrivateKey(account: reloadedAccount, password: updatedPassword), privateKey)
    }

    func testLegacyOversizedEncryptedKeyUsesFirst32BytesAcrossKeyStoreAPIs() throws {
        let legacy = try makeLegacyOversizedEncryptedKey()
        XCTAssertGreaterThan(try legacy.key.decrypt(password: password).count, legacy.privateKey.count)

        let store = try KeyStore(keyDirectory: keyDirectory)
        let account = Account(address: legacy.key.address,
                              type: .encryptedKey,
                              url: keyDirectory.appendingPathComponent("legacy-oversized.json"))
        try store.addKey(key: legacy.key)
        try store.addAccount(account: account)

        XCTAssertEqual(try store.exportPrivateKey(account: account, password: password), legacy.privateKey)

        let exported = try store.export(account: account, password: password, newPassword: password)
        let exportedKey = try JSONDecoder().decode(KeystoreKey.self, from: exported)
        XCTAssertEqual(exportedKey.type, .encryptedKey)
        XCTAssertEqual(try exportedKey.decrypt(password: password), legacy.privateKey)

        let updatedPassword = "updated-keystore-password"
        try store.update(account: account, password: password, newPassword: updatedPassword)
        XCTAssertEqual(try store.exportPrivateKey(account: account, password: updatedPassword), legacy.privateKey)

        let target = try KeyStore(keyDirectory: keyDirectory.appendingPathComponent("legacy-imported"))
        let imported = try target.import(json: legacy.json, password: password, newPassword: updatedPassword)
        XCTAssertEqual(imported.address, legacy.key.address)
        XCTAssertEqual(try target.exportPrivateKey(account: imported, password: updatedPassword), legacy.privateKey)
    }

    /// A keystore whose declared address disagrees with the decrypted secret is tampered with.
    func testImportRejectsAddressMismatch() throws {
        let store = try KeyStore(keyDirectory: keyDirectory)
        let account = try store.import(mnemonic: mnemonic, encryptPassword: password)
        let json = try store.export(account: account, password: password, newPassword: password)

        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: json, options: []) as? [String: Any])
        object["address"] = String(repeating: "1", count: 42)
        let tampered = try JSONSerialization.data(withJSONObject: object, options: [])

        let target = try KeyStore(keyDirectory: keyDirectory.appendingPathComponent("tampered"))
        XCTAssertThrowsError(try target.import(json: tampered, password: password, newPassword: password)) { error in
            switch error as? KeyStore.Error {
            case .invalidKey: break
            default: XCTFail("expected invalidKey, got \(error)")
            }
        }
    }

    /// Mnemonic bytes must never be accepted as a raw secp256k1 scalar, at any length.
    func testKeystoreKeyRejectsMnemonicASCIIPayload() throws {
        let payload = try XCTUnwrap(mnemonic.data(using: .ascii))
        assertRejectsPrivateKey(payload)
        assertRejectsPrivateKey(payload.prefix(32))
    }

    /// 32 bytes of printable ASCII form a valid scalar, so only the guard rejects them.
    func testKeystoreKeyRejectsAllPrintableASCIIInput() {
        assertRejectsPrivateKey(Data(repeating: 0x41, count: 32))
    }

    /// The guard must not reject legitimate keys.
    func testKeystoreKeyAcceptsValid32BytePrivateKey() throws {
        let privateKey = try Wallet(mnemonic: mnemonic).getKey(at: 0).privateKey
        XCTAssertEqual(privateKey.count, 32)
        XCTAssertEqual(try KeystoreKey(password: password, key: privateKey).type, .encryptedKey)
    }

    func testConcurrentImportStoresOneAccount() throws {
        let password = self.password
        let key = try KeystoreKey(password: password, mnemonic: mnemonic)
        let json = try JSONEncoder().encode(key)
        let store = try KeyStore(keyDirectory: keyDirectory)
        let queue = DispatchQueue(label: "org.tronlink.keystore.concurrent-import", attributes: .concurrent)
        let start = DispatchSemaphore(value: 0)
        let ready = DispatchGroup()
        let group = DispatchGroup()
        let resultLock = NSLock()
        var successCount = 0
        var duplicateCount = 0
        var unexpectedErrors = [Swift.Error]()

        for _ in 0..<2 {
            ready.enter()
            group.enter()
            queue.async {
                ready.leave()
                start.wait()
                defer { group.leave() }
                do {
                    _ = try store.import(json: json, password: password, newPassword: password)
                    resultLock.lock()
                    successCount += 1
                    resultLock.unlock()
                } catch KeyStore.Error.accountAlreadyExists {
                    resultLock.lock()
                    duplicateCount += 1
                    resultLock.unlock()
                } catch {
                    resultLock.lock()
                    unexpectedErrors.append(error)
                    resultLock.unlock()
                }
            }
        }

        guard ready.wait(timeout: .now() + 5) == .success else {
            start.signal()
            start.signal()
            if group.wait(timeout: .now() + 60) != .success {
                shouldRemoveKeyDirectory = false
            }
            XCTFail("concurrent import workers failed to start")
            return
        }
        start.signal()
        start.signal()
        guard group.wait(timeout: .now() + 60) == .success else {
            // ponytail: synchronous import cannot be cancelled; use a subprocess if timeout cleanup becomes necessary.
            shouldRemoveKeyDirectory = false
            XCTFail("concurrent imports timed out")
            return
        }

        XCTAssertEqual(successCount, 1)
        XCTAssertEqual(duplicateCount, 1)
        XCTAssertTrue(unexpectedErrors.isEmpty, "unexpected errors: \(unexpectedErrors)")
        XCTAssertEqual(store.accounts.count, 1)
        let account = try XCTUnwrap(store.accounts.first)
        XCTAssertNotNil(store.key(for: account.address))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(at: keyDirectory, includingPropertiesForKeys: []).count, 1)
        XCTAssertEqual(try KeyStore(keyDirectory: keyDirectory).accounts.count, 1)
    }

    // MARK: - TL-KDF-002: scrypt parameters arriving from untrusted keystore JSON

    /// Every preset the app has ever written to disk, plus the desktop preset users import
    /// from, must keep validating. A regression here bricks existing wallets rather than
    /// merely rejecting an import, so this is the guard rail on the new upper bounds.
    func testValidateAcceptsShippedAndStandardPresets() {
        let salt = Data(repeating: 0xAB, count: 32)
        let presets: [(String, Int, Int, Int)] = [
            ("light — what 1.0.4 wrote on disk", ScryptParams.lightN, ScryptParams.defaultR, ScryptParams.lightP),
            ("balanced — current default", ScryptParams.balancedN, ScryptParams.defaultR, ScryptParams.balancedP),
            ("go-ethereum standard — imported from desktop", ScryptParams.standardN, ScryptParams.defaultR, ScryptParams.standardP),
            // The memory ceiling itself: 128 * 8 * 2^19 == 512 MiB exactly. Pinning the
            // boundary from the accepting side catches an off-by-one that would silently
            // start rejecting the strongest configuration we intend to support.
            ("largest n the memory cap admits at r = 8", 1 << 19, ScryptParams.defaultR, 1),
        ]
        for (label, n, r, p) in presets {
            XCTAssertNoThrow(
                try ScryptParams(salt: salt, n: n, r: r, p: p, desiredKeyLength: ScryptParams.defaultDesiredKeyLength),
                "\(label) must remain valid"
            )
        }
    }

    /// The `r` / `p` / `dklen` ceilings deliberately match Android's
    /// `org.tron.net.KeyStoreUtils`, which rejects `r` outside 1...64, `p` outside 1...16
    /// and `dklen` outside 32...1024. A keystore is a file users carry between the two
    /// apps, so a file accepted on one must be accepted on the other.
    func testValidateMatchesAndroidBoundsForRPAndDklen() {
        let salt = Data(repeating: 0xAB, count: 32)

        // Exactly Android's ceilings — must be accepted.
        XCTAssertNoThrow(try ScryptParams(salt: salt, n: 4096, r: 64, p: 1, desiredKeyLength: 32))
        XCTAssertNoThrow(try ScryptParams(salt: salt, n: 4096, r: 8, p: 16, desiredKeyLength: 32))
        XCTAssertNoThrow(try ScryptParams(salt: salt, n: 4096, r: 8, p: 1, desiredKeyLength: 1024))

        // One past each — must be refused on both clients.
        XCTAssertThrowsError(try ScryptParams(salt: salt, n: 4096, r: 65, p: 1, desiredKeyLength: 32))
        XCTAssertThrowsError(try ScryptParams(salt: salt, n: 4096, r: 8, p: 17, desiredKeyLength: 32))
        XCTAssertThrowsError(try ScryptParams(salt: salt, n: 4096, r: 8, p: 1, desiredKeyLength: 1025))

        // At r = 1 the memory rule alone would allow 2^22, which Android rejects. The flat
        // `maxN` ceiling keeps the two clients from diverging in that direction too.
        XCTAssertNoThrow(try ScryptParams(salt: salt, n: 1 << 20, r: 1, p: 1, desiredKeyLength: 32))
        XCTAssertThrowsError(try ScryptParams(salt: salt, n: 1 << 21, r: 1, p: 1, desiredKeyLength: 32))
        XCTAssertThrowsError(try ScryptParams(salt: salt, n: 1 << 22, r: 1, p: 1, desiredKeyLength: 32))
    }

    /// Android refuses a keystore carrying no scrypt salt, and so must we: deriving from
    /// an empty salt makes the KDF output depend on the password alone.
    func testValidateRejectsEmptySalt() {
        XCTAssertThrowsError(
            try ScryptParams(salt: Data(), n: 4096, r: 8, p: 1, desiredKeyLength: 32)
        ) { error in
            guard let validationError = error as? ScryptParams.ValidationError,
                  case .emptySalt = validationError else {
                XCTFail("Expected emptySalt, got \(error)")
                return
            }
        }
    }

    /// Hostile values must be *rejected*, not trapped.
    ///
    /// Before TL-KDF-002 the negative and zero cases below crashed inside `validate()`
    /// itself — `UInt64(-1)` on the block-size line, and division by `p`/`r` on the
    /// overflow line — so this test would have taken the whole runner down instead of
    /// failing. `dklen = 0` and the oversized `n` values were accepted outright and blew
    /// up further downstream, in `decrypt`'s slicing and in the scrypt allocator.
    func testValidateRejectsHostileParametersWithoutTrapping() {
        let salt = Data(repeating: 0xAB, count: 32)
        let hostile: [(String, Int, Int, Int, Int)] = [
            ("negative r", 4096, -1, 1, 32),
            ("zero r", 4096, 0, 1, 32),
            ("zero p", 4096, 8, 0, 32),
            ("negative p", 4096, 8, -1, 32),
            ("zero n", 0, 8, 1, 32),
            ("negative n", -4096, 8, 1, 32),
            ("n not a power of two", 4097, 8, 1, 32),
            ("n one step past the memory cap", 1 << 20, 8, 1, 32),
            ("n = 2^40", 1 << 40, 8, 1, 32),
            ("dklen 0", 4096, 8, 1, 0),
            ("dklen 16 — decrypt's two slices would overlap", 4096, 8, 1, 16),
            ("negative dklen", 4096, 8, 1, -1),
            ("dklen Int.max", 4096, 8, 1, Int.max),
            ("dklen past its cap", 4096, 8, 1, 1025),
            ("r past its cap", 4096, 65, 1, 32),
            ("p past its cap", 4096, 8, 17, 32),
        ]
        for (label, n, r, p, dklen) in hostile {
            XCTAssertThrowsError(
                try ScryptParams(salt: salt, n: n, r: r, p: p, desiredKeyLength: dklen),
                "\(label) must be rejected"
            ) { error in
                XCTAssertTrue(
                    error is ScryptParams.ValidationError,
                    "\(label) must fail with a typed ValidationError, got \(error)"
                )
            }
        }
    }

    /// Backward compatibility, end to end. The light preset is what every install predating
    /// TL-KDF-001 has sitting on disk, so the new bounds must let those files through.
    /// Loading never decrypts — `KeystoreKey(contentsOf:)` only decodes — so the bounds are
    /// first reached at unlock time, and this asserts scrypt actually runs to completion there.
    func testLegacyLightPresetStillDerivesUnderNewBounds() throws {
        let params = try ScryptParams(salt: Data(repeating: 0xAB, count: 32),
                                      n: ScryptParams.lightN,
                                      r: ScryptParams.defaultR,
                                      p: ScryptParams.lightP,
                                      desiredKeyLength: ScryptParams.defaultDesiredKeyLength)
        XCTAssertNil(params.validate())
        XCTAssertEqual(try Scrypt(params: params).calculate(password: password).count, 32)

        // And through the file path: a light-preset keystore must fail on its deliberately
        // junk MAC, never on parameter validation — that is what proves it got through.
        let json = makeKeystoreJSON(n: ScryptParams.lightN,
                                    r: ScryptParams.defaultR,
                                    p: ScryptParams.lightP,
                                    dklen: ScryptParams.defaultDesiredKeyLength)
        let key = try JSONDecoder().decode(KeystoreKey.self, from: json)
        XCTAssertThrowsError(try key.decrypt(password: password)) { error in
            XCTAssertFalse(error is ScryptParams.ValidationError,
                           "The light preset must not be rejected by the new bounds, got \(error)")
        }
    }

    /// The actual attack path, end to end: a keystore file carrying hostile kdfparams.
    ///
    /// Decoding must stay permissive — `KeyStore.load()` silently skips files it cannot
    /// decode, so tightening `init(from:)` would make a wallet vanish from the list with
    /// no error at all. The rejection belongs at decryption time, where it surfaces as a
    /// catchable error.
    func testHostileKDFParamsDecodeButFailToDecrypt() throws {
        let hostile: [(String, Int, Int, Int, Int)] = [
            ("negative r", 4096, -1, 1, 32),
            ("zero p", 4096, 8, 0, 32),
            ("dklen 0", 4096, 8, 1, 0),
            ("n = 2^40", 1 << 40, 8, 1, 32),
        ]
        for (label, n, r, p, dklen) in hostile {
            let json = makeKeystoreJSON(n: n, r: r, p: p, dklen: dklen)
            let key = try JSONDecoder().decode(KeystoreKey.self, from: json)
            XCTAssertEqual(key.crypto.kdfParams.n, n, "\(label): decoding must stay permissive")
            XCTAssertThrowsError(
                try key.decrypt(password: password),
                "\(label) must throw rather than trap or exhaust memory"
            )
        }
    }

    /// Builds a syntactically valid V3 keystore carrying arbitrary kdfparams. The MAC is
    /// junk on purpose: these files must be rejected on their parameters, long before any
    /// password check could matter.
    private func makeKeystoreJSON(n: Int, r: Int, p: Int, dklen: Int) -> Data {
        let json: [String: Any] = [
            "address": "410000000000000000000000000000000000000000",
            "type": "private-key",
            "id": UUID().uuidString.lowercased(),
            "version": 3,
            "crypto": [
                "ciphertext": String(repeating: "00", count: 32),
                "cipher": "aes-128-ctr",
                "cipherparams": ["iv": String(repeating: "00", count: 16)],
                "kdf": "scrypt",
                "kdfparams": [
                    "salt": String(repeating: "00", count: 32),
                    "dklen": dklen,
                    "n": n,
                    "p": p,
                    "r": r,
                ],
                "mac": String(repeating: "00", count: 32),
            ],
        ]
        // Force-try is fine here: the literal above is always serializable.
        return try! JSONSerialization.data(withJSONObject: json)
    }

    private func makeLegacyOversizedEncryptedKey() throws -> (key: KeystoreKey, privateKey: Data, json: Data) {
        let privateKey = try Wallet(mnemonic: mnemonic).getKey(at: 0).privateKey
        var payload = privateKey
        payload.append(contentsOf: Array(" legacy oversized encrypted-key payload".utf8))

        var key = try KeystoreKey(password: password, key: privateKey)
        key.crypto = try KeystoreKeyHeader(password: password, data: payload)
        key.type = .encryptedKey
        return (key, privateKey, try JSONEncoder().encode(key))
    }

    private func assertRejectsPrivateKey(_ key: Data, file: StaticString = #file, line: UInt = #line) {
        XCTAssertThrowsError(try KeystoreKey(password: password, key: key), file: file, line: line) { error in
            switch error as? EncryptError {
            case .invalidPrivateKey: break
            default: XCTFail("expected invalidPrivateKey, got \(error)", file: file, line: line)
            }
        }
    }
}

extension EmbeddedKeystoreTests {
    func testUppercaseCryptoJSONRemainsDecodable() throws {
        let privateKey = Data(repeating: 0, count: 31) + Data([1])
        let key = try KeystoreKey(password: password, key: privateKey)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(
            with: JSONEncoder().encode(key),
            options: []
        ) as? [String: Any])
        object["Crypto"] = object.removeValue(forKey: "crypto")
        let decoded = try JSONDecoder().decode(
            KeystoreKey.self,
            from: JSONSerialization.data(withJSONObject: object, options: [])
        )
        XCTAssertEqual(try decoded.decrypt(password: password), privateKey)
        XCTAssertEqual(decoded.version, 3)
        XCTAssertEqual(decoded.type, .encryptedKey)
    }

    func testAES128CBCKeystoreRemainsDecryptable() throws {
        let privateKey = Data(repeating: 0, count: 31) + Data([1])
        var key = try KeystoreKey(password: password, key: privateKey)
        let derivedKey = try Scrypt(params: key.crypto.kdfParams).calculate(password: password)
        let iv = Data(repeating: 0x22, count: CipherParams.blockSize)
        let cipherText = try AES(
            key: Array(derivedKey[0...15]),
            blockMode: CBC(iv: Array(iv)),
            padding: .noPadding
        ).encrypt(Array(privateKey))
        key.crypto.cipher = "aes-128-cbc"
        key.crypto.cipherParams.iv = iv
        key.crypto.cipherText = Data(cipherText)
        key.crypto.mac = KeystoreKey.computeMAC(
            prefix: derivedKey[(derivedKey.count - 16)..<derivedKey.count],
            key: key.crypto.cipherText
        )
        XCTAssertEqual(try key.decrypt(password: password), privateKey)
    }

    func testEncodedAddressRemainsLowercaseAndPrefixFree() throws {
        let privateKey = Data(repeating: 0, count: 31) + Data([1])
        var key = try KeystoreKey(password: password, key: privateKey)
        key.address = Address(data: Data(repeating: 0, count: 21))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(
            with: JSONEncoder().encode(key),
            options: []
        ) as? [String: Any])
        XCTAssertEqual(object["address"] as? String, String(repeating: "0", count: 42))
    }
}
