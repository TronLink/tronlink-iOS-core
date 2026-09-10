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

    func testBase58RoundTripsLeadingZeroBytes() {
        let rotatedAlphabet = Array(Base58String.btcAlphabet.dropFirst()) + [Base58String.btcAlphabet[0]]
        let alphabets = [Base58String.btcAlphabet, Base58String.flickrAlphabet, rotatedAlphabet]
        let payloads = [
            Data(),
            Data([0x00]),
            Data([0x00, 0x00]),
            Data([0x00, 0x00, 0x01, 0x02, 0x03]),
            Data([0x01, 0x02, 0x03]),
        ]

        for (alphabetIndex, alphabet) in alphabets.enumerated() {
            for payload in payloads {
                let encoded = String(base58Encoding: payload, alphabet: alphabet)
                XCTAssertEqual(Data(base58Decoding: encoded, alphabet: alphabet), payload,
                               "raw Base58 round trip failed for alphabet \(alphabetIndex)")

                let checkEncoded = String(base58CheckEncoding: payload, alphabet: alphabet)
                XCTAssertEqual(Data(base58CheckDecoding: checkEncoded, alphabet: alphabet), payload,
                               "Base58Check round trip failed for alphabet \(alphabetIndex)")
            }
        }
    }

    func testBase58CanonicalVectorsPreserveLeadingZeroBytes() {
        let vectors: [(alphabet: [UInt8], bytes: Data, encoded: String)] = [
            (Base58String.btcAlphabet, Data(), ""),
            (Base58String.btcAlphabet, Data([0x0a]), "B"),
            (Base58String.btcAlphabet, Data([0x00]), "1"),
            (Base58String.btcAlphabet, Data([0x00, 0x00]), "11"),
            (Base58String.btcAlphabet, Data([0x00, 0x0a]), "1B"),
            (Base58String.btcAlphabet, Data([0x00, 0x00, 0x0a]), "11B"),
            (Base58String.flickrAlphabet, Data(), ""),
            (Base58String.flickrAlphabet, Data([0x0a]), "b"),
            (Base58String.flickrAlphabet, Data([0x00]), "1"),
            (Base58String.flickrAlphabet, Data([0x00, 0x00]), "11"),
            (Base58String.flickrAlphabet, Data([0x00, 0x0a]), "1b"),
            (Base58String.flickrAlphabet, Data([0x00, 0x00, 0x0a]), "11b"),
        ]

        for vector in vectors {
            XCTAssertEqual(String(base58Encoding: vector.bytes, alphabet: vector.alphabet),
                           vector.encoded)
            XCTAssertEqual(Data(base58Decoding: vector.encoded, alphabet: vector.alphabet),
                           vector.bytes)
        }
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
    
    // Sign serialized transaction data without depending on a live full node.
    func testSignTransaction() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }

        let password = "transaction-signing-password"
        let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
        let store = try KeyStore(keyDirectory: directory)
        let account = try store.import(mnemonic: mnemonic, encryptPassword: password)
        let walletAddress = String(base58CheckEncoding: account.address.data)

        let transfer = TransferContract()
        transfer.ownerAddress = account.address.data
        transfer.toAddress = account.address.data
        transfer.amount = 1

        let contract = Transaction_Contract()
        contract.type = .transferContract
        contract.parameter.typeURL = "type.googleapis.com/protocol.TransferContract"
        contract.parameter.value = try XCTUnwrap(transfer.data())

        let rawData = Transaction_raw()
        rawData.refBlockHash = Data(repeating: 0x11, count: 8)
        rawData.refBlockBytes = Data([0x12, 0x34])
        rawData.contractArray = [contract]
        let serialized = try XCTUnwrap(rawData.data())

        let signature: Data
        switch TLWalletCore.signTranscation(keyStore: store,
                                            transaction: serialized,
                                            password: password,
                                            address: walletAddress) {
        case .success(let value):
            signature = value
        case .failure(let error):
            return XCTFail("Failed to sign serialized transaction: \(error)")
        }

        guard signature.count == 65 else {
            return XCTFail("Expected a 65-byte recoverable signature, got \(signature.count) bytes")
        }
        XCTAssertLessThan(signature[64], 4)

        let digest = serialized.sha256T()
        let fixtureWallet = try Wallet(mnemonic: mnemonic)
        defer { fixtureWallet.clear() }
        let expectedPublicKey = try fixtureWallet.getKey(at: 0).publicKey
        let recoveredPublicKey = try SECP256K1.recoverPublicKey(hash: digest, signature: signature)
        XCTAssertEqual(recoveredPublicKey, expectedPublicKey)

        XCTAssertEqual(account.address.data.count, 21)
        XCTAssertEqual(account.address.data.first, 0x41)
        let expectedAddress = Data(account.address.data.dropFirst())
        XCTAssertEqual(try Web3Utils.publicToAddressData(recoveredPublicKey), expectedAddress)
        XCTAssertEqual(try Web3Utils.hashECRecover(hash: digest, signature: signature).addressData,
                       expectedAddress)

        for chainId in ["abc", "0xabc", "1g", "g1", "0x"] {
            guard case .failure(.failedToSignTransaction) = TLWalletCore.signTranscation(
                keyStore: store, transaction: serialized, password: password, address: walletAddress, chainId
            ) else {
                return XCTFail("Malformed chain ID must not produce a signature: \(chainId)")
            }
            let transaction = TronTransaction()
            transaction.rawData = rawData
            guard case .failure(.failedToSignTransaction) = TLWalletCore.signTranscation(
                keyStore: store, transaction: transaction, password: password, address: walletAddress, chainId
            ) else {
                return XCTFail("Malformed chain ID must not sign a transaction: \(chainId)")
            }
            XCTAssertEqual(transaction.signatureArray.count, 0)
        }

        let chainBytes = Data(repeating: 0x11, count: 32)
        let chainId = "0x" + chainBytes.hexString
        let chainDigest = (digest + chainBytes).sha256T()
        guard case .success(let chainSignature) = TLWalletCore.signTranscation(
            keyStore: store, transaction: serialized, password: password, address: walletAddress, chainId
        ) else {
            return XCTFail("Valid chain ID should still sign serialized data")
        }
        XCTAssertEqual(try Web3Utils.hashECRecover(hash: chainDigest, signature: chainSignature).addressData,
                       expectedAddress)
        let chainTransaction = TronTransaction()
        chainTransaction.rawData = rawData
        guard case .success = TLWalletCore.signTranscation(
            keyStore: store, transaction: chainTransaction, password: password, address: walletAddress, chainId
        ) else {
            return XCTFail("Valid chain ID should still sign a transaction")
        }
        XCTAssertEqual(chainTransaction.signatureArray.count, 1)
        let objectSignature = try XCTUnwrap(chainTransaction.signatureArray.firstObject as? Data)
        XCTAssertEqual(try Web3Utils.hashECRecover(hash: chainDigest, signature: objectSignature).addressData,
                       expectedAddress)
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

final class SingleTLCorePublicAPITests: XCTestCase {
    func testWalletABIAndWeb3APIsAreAvailableFromTLCore() throws {
        let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
        let wallet = try Wallet(mnemonic: mnemonic)
        let walletKey = try wallet.getKey(at: 0)
        XCTAssertEqual(walletKey.address.data.count, 20)
        XCTAssertEqual(walletKey.privateKey.hexString,
                       "b5a4cea271ff424d7c31dc12a3e43e401df7a40d7412a15750f3f0b6b5449a28")
        let keystoreKey = try KeystoreKey(password: "single-module-smoke", mnemonic: mnemonic)
        XCTAssertEqual(keystoreKey.address.data.first, 0x41)

        let encoder = ABIEncoder()
        try encoder.encode(BigUInt(42))
        XCTAssertEqual(encoder.data.count, 32)

        let privateKey = PrivateKey(Data(repeating: 0, count: 31) + Data([1]))
        try privateKey.verify()
        XCTAssertTrue(privateKey.address.isValid)
        XCTAssertNotNil(ABIv2Encoder.encode(types: [.uint(bits: 256)], values: [BigUInt(42) as AnyObject]))
    }
}

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
        XCTAssertEqual(signature.data.hex,
                       "e7c93726a865578504442b1a6827f676e0ed74bdff2be3960d1e253bbcfc44626aa772b878bc912bdbb33a0014ec507c4b3896ea85aa914b74dee9b7ac3e56da01")
        XCTAssertEqual(signature.v, 1)
        XCTAssertEqual(signature.r.serialize().count, 32)
        XCTAssertLessThanOrEqual(signature.s.serialize().count, 32)
        XCTAssertEqual(try TLCore.Web3Utils.hashECRecover(hash: messageHash, signature: signature.data), key.address)
        XCTAssertEqual(try TLCore.Web3Utils.getAddressFromSignature(messageHash, signature: signature.data.hex), key.address)
    }

    func testPersonalMessageHashMatchesRawByteEnvelopes() throws {
        let cases: [(Data, Data)] = [
            (Data(), Data("\u{19}Ethereum Signed Message:\n0".utf8)),
            (Data("hello".utf8), Data("\u{19}Ethereum Signed Message:\n5hello".utf8)),
            (Data("你好".utf8), Data("\u{19}Ethereum Signed Message:\n6你好".utf8)),
            (Data([0x00, 0xff]), Data("\u{19}Ethereum Signed Message:\n2".utf8) + Data([0x00, 0xff]))
        ]
        for (message, envelope) in cases {
            // Use the separate C-backed Keccak implementation as the digest oracle.
            XCTAssertEqual(try TLCore.Web3Utils.hashPersonalMessage(message),
                           EthereumCrypto.hash(envelope))
        }
    }

    func testPersonalMessageHashDoesNotReuseAnEmbeddedEnvelope() throws {
        let message = Data("0ab".utf8)
        // The valid envelope for "0ab" is also a 30-byte message starting with prefix + "30".
        // The old prefix detection hashed these two different messages identically.
        let wrappedMessage = Data("\u{19}Ethereum Signed Message:\n30ab".utf8)
        XCTAssertEqual(wrappedMessage.count, 30)
        let expectedMessageHash = EthereumCrypto.hash(wrappedMessage)
        let expectedWrappedHash = EthereumCrypto.hash(
            Data("\u{19}Ethereum Signed Message:\n30".utf8) + wrappedMessage
        )

        XCTAssertEqual(try TLCore.Web3Utils.hashPersonalMessage(message), expectedMessageHash)
        XCTAssertEqual(try TLCore.Web3Utils.hashPersonalMessage(wrappedMessage), expectedWrappedHash)
        XCTAssertNotEqual(try TLCore.Web3Utils.hashPersonalMessage(message),
                          try TLCore.Web3Utils.hashPersonalMessage(wrappedMessage))

        let buffer = Data([0xff]) + wrappedMessage
        XCTAssertEqual(try TLCore.Web3Utils.hashPersonalMessage(buffer.dropFirst()), expectedWrappedHash)
    }

    func testPersonalRecoveryBindsSignatureToOriginalMessage() throws {
        let key = TLCore.PrivateKey(privateKeyData)
        let message = Data("0ab".utf8)
        let wrappedMessage = Data("\u{19}Ethereum Signed Message:\n30ab".utf8)
        let signature = try key.sign(hash: EthereumCrypto.hash(wrappedMessage))

        XCTAssertEqual(try TLCore.Web3Utils.personalECRecover(message, signature: signature.data), key.address)
        XCTAssertEqual(try TLCore.Web3Utils.personalECRecover(message.hex, signature: signature.data.hex), key.address)
        XCTAssertNotEqual(try TLCore.Web3Utils.personalECRecover(wrappedMessage, signature: signature.data), key.address)
        XCTAssertNotEqual(try TLCore.Web3Utils.personalECRecover(wrappedMessage.hex, signature: signature.data.hex), key.address)

        let wrappedHash = EthereumCrypto.hash(
            Data("\u{19}Ethereum Signed Message:\n30".utf8) + wrappedMessage
        )
        let wrappedSignature = try key.sign(hash: wrappedHash)
        XCTAssertEqual(try TLCore.Web3Utils.personalECRecover(wrappedMessage, signature: wrappedSignature.data), key.address)
        // Main-app callers that supply a digest keep their existing recovery behavior.
        XCTAssertEqual(try TLCore.Web3Utils.hashECRecover(hash: wrappedHash, signature: wrappedSignature.data), key.address)
        XCTAssertEqual(try TLCore.Web3Utils.getAddressFromSignature(wrappedHash, signature: wrappedSignature.data.hex), key.address)
    }

    func testABIv2EncodingAndDecodingMatchesGoldenValues() throws {
        XCTAssertEqual(try TLCore.ABIv2TypeParser.parseTypeString("(address,uint256[])[]"),
                       .array(type: .tuple(types: [.address, .array(type: .uint(bits: 256), length: 0)]), length: 0))
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
        XCTAssertNil(Data.fromHex("0xabc"))
        XCTAssertEqual(Data.fromHex("0x0abc"), Data([0x0a, 0xbc]))
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

    func testEventLogRemovedAcceptsBooleansAndPreservesLegacyValues() throws {
        var object: [String: Any] = [
            "address": "0x1111111111111111111111111111111111111111",
            "blockHash": "0x" + String(repeating: "00", count: 32),
            "blockNumber": "0x1", "data": "0x", "logIndex": "0x0",
            "topics": [String](),
            "transactionHash": "0x" + String(repeating: "00", count: 32),
            "transactionIndex": "0x0"
        ]
        let cases: [(Any?, Bool)] = [
            (true, true), (false, false),
            ("0x1", true), ("0x0", false), ("0x2", false),
            (nil, false), (NSNull(), false)
        ]
        for (removed, expected) in cases {
            object["removed"] = removed
            let data = try JSONSerialization.data(withJSONObject: object)
            let log = try JSONDecoder().decode(TLCore.EventLog.self, from: data)
            XCTAssertEqual(log.removed, expected, "removed: \(String(describing: removed))")
        }
        // Preserve the existing failure for malformed legacy hex strings.
        object["removed"] = "not-hex"
        let invalid = try JSONSerialization.data(withJSONObject: object)
        XCTAssertThrowsError(try JSONDecoder().decode(TLCore.EventLog.self, from: invalid))
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

    func testAddressEncodingAlwaysWrites32ByteSlot() throws {
        let evm20 = Data(repeating: 0xaa, count: 20)
        let expected = Data(repeating: 0, count: 12) + evm20

        let encoder20 = ABIEncoder()
        try encoder20.encode(Address(data: evm20))
        XCTAssertEqual(encoder20.data, expected)

        let encoder41 = ABIEncoder()
        try encoder41.encode(Address(data: Data([0x41]) + evm20))
        XCTAssertEqual(encoder41.data, expected)

        let encoder00 = ABIEncoder()
        try encoder00.encode(Address(data: Data([0x00]) + evm20))
        XCTAssertEqual(encoder00.data, expected)

        let encoder32 = ABIEncoder()
        try encoder32.encode(Address(data: expected))
        XCTAssertEqual(encoder32.data, expected)
        XCTAssertEqual(encoder32.data.count, 32)
    }

    func testEmptyAddressEncodingThrowsWithoutWritingBytes() {
        let encoder = ABIEncoder()
        let invalidAddresses = [
            Data(),
            Data([0x01]),
            Data([0x42]) + Data(repeating: 0xaa, count: 20),
            Data(repeating: 0xaa, count: 19),
            Data(repeating: 0xaa, count: 22),
            Data([0x01]) + Data(repeating: 0, count: 31),
            Data(repeating: 0xaa, count: 33),
        ]

        for rawAddress in invalidAddresses {
            XCTAssertThrowsError(try encoder.encode(Address(data: rawAddress))) { error in
                XCTAssertEqual(error as? ABIError, .invalidAddress)
            }
            XCTAssertTrue(encoder.data.isEmpty)
        }
    }

    func testTransferFromDoesNotCollapseEmptyToSlot() {
        let from = Address(data: Data(repeating: 0xaa, count: 20))
        let encoder = ABIEncoder()
        let function = Function(name: "transferFrom", parameters: [.address, .address, .uint(bits: 256)])
        XCTAssertThrowsError(try encoder.encode(function: function, arguments: [from, Address(data: Data()), 12345])) { error in
            XCTAssertEqual(error as? ABIError, .invalidAddress)
        }
    }

    func testDynamicFixedArrayAndNestedTupleMatchSolidityABIEncode() throws {
        // Single-value Solidity `abi.encode(T)` (ethers v6 AbiCoder, same layout as solc).
        // Encoding `.tuple([value])` is that 1-tuple wrapper.
        let string2 = ABIValue.array(.string, [.string("a"), .string("bc")])
        let pair = ABIValue.tuple([.string("hello"), .uint(bits: 256, BigUInt(42))])
        let cases: [(String, ABIValue, String)] = [
            (
                "string[2]",
                string2,
                "0000000000000000000000000000000000000000000000000000000000000020" +
                "0000000000000000000000000000000000000000000000000000000000000040" +
                "0000000000000000000000000000000000000000000000000000000000000080" +
                "0000000000000000000000000000000000000000000000000000000000000001" +
                "6100000000000000000000000000000000000000000000000000000000000000" +
                "0000000000000000000000000000000000000000000000000000000000000002" +
                "6263000000000000000000000000000000000000000000000000000000000000"
            ),
            (
                "(string,uint256)",
                pair,
                "0000000000000000000000000000000000000000000000000000000000000020" +
                "0000000000000000000000000000000000000000000000000000000000000040" +
                "000000000000000000000000000000000000000000000000000000000000002a" +
                "0000000000000000000000000000000000000000000000000000000000000005" +
                "68656c6c6f000000000000000000000000000000000000000000000000000000"
            ),
            (
                "(string[2],uint256)",
                .tuple([string2, .uint(bits: 256, BigUInt(7))]),
                "0000000000000000000000000000000000000000000000000000000000000020" +
                "0000000000000000000000000000000000000000000000000000000000000040" +
                "0000000000000000000000000000000000000000000000000000000000000007" +
                "0000000000000000000000000000000000000000000000000000000000000040" +
                "0000000000000000000000000000000000000000000000000000000000000080" +
                "0000000000000000000000000000000000000000000000000000000000000001" +
                "6100000000000000000000000000000000000000000000000000000000000000" +
                "0000000000000000000000000000000000000000000000000000000000000002" +
                "6263000000000000000000000000000000000000000000000000000000000000"
            ),
            (
                "(string,uint256)[2]",
                .array(.tuple([.string, .uint(bits: 256)]), [
                    .tuple([.string("x"), .uint(bits: 256, BigUInt(1))]),
                    .tuple([.string("yz"), .uint(bits: 256, BigUInt(2))])
                ]),
                "0000000000000000000000000000000000000000000000000000000000000020" +
                "0000000000000000000000000000000000000000000000000000000000000040" +
                "00000000000000000000000000000000000000000000000000000000000000c0" +
                "0000000000000000000000000000000000000000000000000000000000000040" +
                "0000000000000000000000000000000000000000000000000000000000000001" +
                "0000000000000000000000000000000000000000000000000000000000000001" +
                "7800000000000000000000000000000000000000000000000000000000000000" +
                "0000000000000000000000000000000000000000000000000000000000000040" +
                "0000000000000000000000000000000000000000000000000000000000000002" +
                "0000000000000000000000000000000000000000000000000000000000000002" +
                "797a000000000000000000000000000000000000000000000000000000000000"
            ),
        ]

        for (name, value, expected) in cases {
            let encoder = ABIEncoder()
            try encoder.encode(.tuple([value]))
            XCTAssertEqual(encoder.data.hexString, expected, name)
        }
    }

    func testERC20ConvenienceEncodersThrowForInvalidAddress() throws {
        let invalid = Address(data: Data())
        let valid = Address(data: Data(repeating: 0xaa, count: 20))
        let encoders: [() throws -> Data] = [
            { try ERC20Encoder.encodeBalanceOf(address: invalid) },
            { try ERC20Encoder.encodeAllowance(owner: valid, spender: invalid) },
            { try ERC20Encoder.encodeTransfer(to: invalid, tokens: 1) },
            { try ERC20Encoder.encodeTransfer(from: valid, to: invalid, tokens: 1) },
            { try ERC20Encoder.encodeApprove(spender: invalid, tokens: 1) },
            { try ERC20Encoder.encodeDepositTRC20(spender: invalid, tokens: 1) },
            { try ERC20Encoder.encodeExchangeBalance(contractOwner: valid, tokens: [invalid]) }
        ]
        for encode in encoders {
            XCTAssertThrowsError(try encode()) { error in
                XCTAssertEqual(error as? ABIError, .invalidAddress)
            }
        }
        let addressWord = String(repeating: "0", count: 24) + String(repeating: "aa", count: 20)
        let amountWord = String(repeating: "0", count: 63) + "1"
        XCTAssertEqual(try ERC20Encoder.encodeApprove(spender: valid, tokens: 1).hexString,
                       "095ea7b3" + addressWord + amountWord)
        XCTAssertEqual(try ERC20Encoder.encodeTransfer(to: valid, tokens: 1).hexString,
                       "a9059cbb" + addressWord + amountWord)
        XCTAssertEqual(try ERC20Encoder.encodeTransfer(from: valid, to: valid, tokens: 1).hexString,
                       "23b872dd" + addressWord + addressWord + amountWord)
    }

    func testERC20HelpersThrowOnOverflowInsteadOfTrappingOrReturningEmptyData() throws {
        let valid = Address(data: Data(repeating: 0xaa, count: 20))
        let overflow = BigUInt(1) << 256
        let encoders: [() throws -> Data] = [
            { try ERC20Encoder.encodeOwnerOf(tokenId: overflow) },
            { try ERC20Encoder.encodeTransfer(to: valid, tokens: overflow) },
            { try ERC20Encoder.encodeApprove(spender: valid, tokens: overflow) },
            { try ERC20Encoder.encodeDepositTRC10(tokenId: overflow, tokens: 1) },
            { try ERC20Encoder.encodeWithdrawTRC10(tokenId: 1, tokens: overflow) },
            { try ERC20Encoder.encodeWithdrawTRC20(tokens: overflow) },
            { try ERC20Encoder.encodetTrxToTokenSwapInput(minTokens: overflow, deadline: 1) },
            { try ERC20Encoder.encodeTokenToTokenSwapInput(tokensSold: overflow, minTokensBought: 1,
                                                         minTrxBought: 1, deadline: 1, tokenAddr: valid) }
        ]
        for encode in encoders {
            XCTAssertThrowsError(try encode()) { error in
                XCTAssertEqual(error as? ABIError, .integerOverflow)
            }
        }
        XCTAssertEqual(try ERC20Encoder.encodeOwnerOf(tokenId: overflow - 1).hexString,
                       "6352211e" + String(repeating: "f", count: 64))
    }

    func testSwapHelperRejectsInvalidTupleArguments() throws {
        let valid = Address(data: Data(repeating: 0xaa, count: 20))
        let cases: [([Any], ABIError)] = [
            ([BigUInt(1), BigUInt(2), valid], .invalidNumberOfArguments),
            ([BigUInt(1), BigUInt(2), valid, BigUInt(3), BigUInt(4)], .invalidNumberOfArguments),
            (["invalid", BigUInt(2), valid, BigUInt(3)], .invalidArgumentType),
            ([-1, BigUInt(2), valid, BigUInt(3)], .integerOverflow)
        ]
        for (tuple, expected) in cases {
            XCTAssertThrowsError(try ERC20Encoder.encodeSwapExactInput(path: [valid], poolVersion: ["v1"],
                versionLen: [1], fees: [0], tuple: tuple)) { error in
                XCTAssertEqual(error as? ABIError, expected)
            }
        }
    }

    func testERC20FixedSelectorsRemainNonThrowing() {
        XCTAssertEqual(ERC20Encoder.encodeTotalSupply().hexString, "18160ddd")
        XCTAssertEqual(ERC20Encoder.encodeName().hexString, "06fdde03")
        XCTAssertEqual(ERC20Encoder.encodeSymbol().hexString, "95d89b41")
        XCTAssertEqual(ERC20Encoder.encodeDecimals().hexString, "313ce567")
        XCTAssertEqual(ERC20Encoder.encodeDepositTRX().count, 4)
        XCTAssertEqual(ERC20Encoder.encodeWithdrawTRX().count, 4)
        XCTAssertEqual(ERC20Encoder.encodeWithdrawFee().count, 4)
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
        var zeroAddressData = Data([0x41])
        zeroAddressData.append(Data(repeating: 0, count: 20))
        XCTAssertEqual(zeroAddress.base58CheckData, zeroAddressData)
        XCTAssertEqual(String(base58CheckEncoding: zeroAddressData), zeroAddress)
    }

    func testProtobufAddressRetainsBehaviorUnderSwiftRename() {
        let proto = TronProtoAddress()
        proto.host = Data([127, 0, 0, 1])
        proto.port = 18888
        XCTAssertEqual(proto.host, Data([127, 0, 0, 1]))
        XCTAssertEqual(proto.port, 18888)
    }
}
final class ABIValueBoundsTests: XCTestCase {
    private func encoded(_ value: ABIValue) throws -> Data {
        let encoder = ABIEncoder()
        try encoder.encode(value)
        return encoder.data
    }

    func testEveryIntegerWidthPreservesBoundaryWordsAndRejectsOverflow() throws {
        for byteCount in 1...32 {
            let bits = byteCount * 8
            let unsignedMaximum = (BigUInt(1) << bits) - 1
            let signedLimit = BigInt(1) << (bits - 1)
            let signedMaximum = signedLimit - 1
            let signedMinimum = -signedLimit
            let unsignedWord = Data(repeating: 0, count: 32 - byteCount) + Data(repeating: 0xff, count: byteCount)
            let signedMaxWord = Data(repeating: 0, count: 32 - byteCount)
                + Data([0x7f]) + Data(repeating: 0xff, count: byteCount - 1)
            let signedMinWord = Data(repeating: 0xff, count: 32 - byteCount)
                + Data([0x80]) + Data(repeating: 0, count: byteCount - 1)

            XCTAssertEqual(try encoded(ABIValue(BigUInt(0), type: .uint(bits: bits))), Data(repeating: 0, count: 32))
            XCTAssertEqual(try encoded(ABIValue(unsignedMaximum, type: .uint(bits: bits))), unsignedWord)
            XCTAssertEqual(try encoded(ABIValue(signedMaximum, type: .int(bits: bits))), signedMaxWord)
            XCTAssertEqual(try encoded(ABIValue(signedMinimum, type: .int(bits: bits))), signedMinWord)
            XCTAssertThrowsError(try ABIValue(unsignedMaximum + 1, type: .uint(bits: bits)))
            XCTAssertThrowsError(try ABIValue(signedMaximum + 1, type: .int(bits: bits)))
            XCTAssertThrowsError(try ABIValue(signedMinimum - 1, type: .int(bits: bits)))
            XCTAssertThrowsError(try encoded(.uint(bits: bits, unsignedMaximum + 1)))
            XCTAssertThrowsError(try encoded(.int(bits: bits, signedMaximum + 1)))
            XCTAssertThrowsError(try encoded(.int(bits: bits, signedMinimum - 1)))
        }
        XCTAssertThrowsError(try ABIValue(256, type: .uint(bits: 8)))
        XCTAssertThrowsError(try ABIValue(UInt(256), type: .uint(bits: 8)))
        XCTAssertThrowsError(try ABIValue(-1, type: .uint(bits: 8)))
        XCTAssertThrowsError(try ABIValue(128, type: .int(bits: 8)))
    }

    func testInvalidDeclarationsFailBeforeShiftsOrPadding() {
        for bits in [Int.min, -8, 0, 7, 9, 257, Int.max] {
            XCTAssertThrowsError(try ABIValue(BigUInt(0), type: .uint(bits: bits)))
            XCTAssertThrowsError(try encoded(.int(bits: bits, 0)))
            XCTAssertThrowsError(try ABIValue([] as [Any], type: .dynamicArray(.uint(bits: bits))))
        }
        for length in [Int.min, 0, 33, Int.max] {
            XCTAssertThrowsError(try ABIValue(Data(), type: .bytes(length)))
        }
        XCTAssertThrowsError(try ABIValue([] as [Any], type: .array(.bool, -1)))
        for scale in [0, 81, Int.max] {
            XCTAssertThrowsError(try ABIValue(BigInt(0), type: .fixed(128, scale)))
            XCTAssertThrowsError(try encoded(.ufixed(bits: 128, scale, 0)))
        }
    }

    func testFixedPointUsesTheDeclaredBoundsForItsScaledInteger() throws {
        XCTAssertEqual(try encoded(ABIValue(BigInt(-128), type: .fixed(8, 2))),
                       Data(repeating: 0xff, count: 31) + Data([0x80]))
        XCTAssertEqual(try encoded(ABIValue(BigUInt(255), type: .ufixed(8, 2))),
                       Data(repeating: 0, count: 31) + Data([0xff]))
        XCTAssertThrowsError(try ABIValue(BigInt(128), type: .fixed(8, 2)))
        XCTAssertThrowsError(try encoded(.fixed(bits: 8, 2, -129)))
        XCTAssertThrowsError(try ABIValue(BigUInt(256), type: .ufixed(8, 2)))
    }

    func testFixedBytesKeepRightPaddingAndTheirDeclaredArrayType() throws {
        for length in 1...32 {
            for count in [0, 1, length] {
                let bytes = Data(repeating: 0xab, count: count)
                let value = try ABIValue(bytes, type: .bytes(length))
                XCTAssertEqual(value.type, .bytes(length))
                XCTAssertEqual(value.length, 32)
                XCTAssertEqual(try encoded(value), bytes + Data(repeating: 0, count: 32 - count))
            }
            XCTAssertThrowsError(try ABIValue(Data(repeating: 1, count: length + 1), type: .bytes(length)))
        }

        let bytes: [Any] = [Data([0xaa]), Data()]
        let value = try ABIValue(bytes, type: .array(.bytes(2), 2))
        XCTAssertEqual(try encoded(value), Data([0xaa]) + Data(repeating: 0, count: 63))
        XCTAssertThrowsError(try encoded(.bytes(Data())))
        XCTAssertThrowsError(try encoded(.bytes(Data(repeating: 1, count: 33))))

        let dynamic = ABIEncoder()
        try dynamic.encode(Data(repeating: 0xab, count: 33), static: false)
        XCTAssertEqual(dynamic.data.count, 96)
        XCTAssertEqual(dynamic.data.prefix(32), Data(repeating: 0, count: 31) + Data([33]))
    }

    func testFixedArrayAndTupleCountsMustMatchAtEveryLevel() throws {
        let invalidArrays: [[Any]] = [[1], [1, 2, 3]]
        for values in invalidArrays {
            XCTAssertThrowsError(try ABIValue(values, type: .array(.uint(bits: 8), 2))) { error in
                XCTAssertEqual(error as? ABIError, .invalidNumberOfArguments)
            }
            XCTAssertThrowsError(try ABIValue(values, type: .tuple([.uint(bits: 8), .uint(bits: 8)]))) { error in
                XCTAssertEqual(error as? ABIError, .invalidNumberOfArguments)
            }
            XCTAssertThrowsError(try ABIValue([values] as [Any], type: .dynamicArray(.array(.uint(bits: 8), 2))))
        }
        let values: [Any] = [1, 2]
        let array = try ABIValue(values, type: .array(.uint(bits: 8), 2))
        XCTAssertEqual(try encoded(array),
                       Data(repeating: 0, count: 31) + Data([1]) + Data(repeating: 0, count: 31) + Data([2]))
    }

    func testDirectEnumValuesFailBeforeWritingTupleOrFunctionData() {
        let invalidValues: [ABIValue] = [
            .tuple([.uint(bits: 256, 1), .uint(bits: 8, 256)]),
            .dynamicArray(.uint(bits: 8), [.uint(bits: 8, 1), .uint(bits: 8, 256)]),
            .array(.uint(bits: 8), [.bool(true)]),
            .function(Function(name: "f", parameters: [.uint(bits: 8)]), [])
        ]
        for value in invalidValues {
            let encoder = ABIEncoder()
            encoder.data = Data([0xde, 0xad])
            XCTAssertThrowsError(try encoder.encode(value))
            XCTAssertEqual(encoder.data, Data([0xde, 0xad]))
        }

        let encoder = ABIEncoder()
        encoder.data = Data([0xde, 0xad])
        XCTAssertThrowsError(try encoder.encode(function: Function(name: "f", parameters: [.uint(bits: 8)]), arguments: [256]))
        XCTAssertEqual(encoder.data, Data([0xde, 0xad]))
        XCTAssertThrowsError(try encoder.encode(tuple: [.uint(bits: 256, 1), .bytes(Data(repeating: 1, count: 33))]))
        XCTAssertEqual(encoder.data, Data([0xde, 0xad]))
    }

    func testRawSignedEncoderRejectsOverflowAndNormalizesNegativeZero() throws {
        let limit = BigInt(1) << 255
        for value in [limit, -limit - 1] {
            let encoder = ABIEncoder()
            XCTAssertThrowsError(try encoder.encode(value))
            XCTAssertTrue(encoder.data.isEmpty)
        }
        var negativeZero = BigInt(0)
        negativeZero.sign = .minus
        let encoder = ABIEncoder()
        try encoder.encode(negativeZero)
        XCTAssertEqual(encoder.data, Data(repeating: 0, count: 32))
    }

    func testPermit2MaximaAndTRC20TransferKeepTheirCalldata() throws {
        let address = Address(data: Data(repeating: 0xaa, count: 20))
        let amount = (BigUInt(1) << 160) - 1
        let expiration = (BigUInt(1) << 48) - 1
        let function = Function(name: "approve", parameters: [.address, .address, .uint(bits: 160), .uint(bits: 48)])
        let encoder = ABIEncoder()
        try encoder.encode(function: function, arguments: [address, address, amount, expiration])
        XCTAssertEqual(encoder.data.count, 132)
        XCTAssertEqual(encoder.data.subdata(in: 68..<100), Data(repeating: 0, count: 12) + Data(repeating: 0xff, count: 20))
        XCTAssertEqual(encoder.data.subdata(in: 100..<132), Data(repeating: 0, count: 26) + Data(repeating: 0xff, count: 6))
        XCTAssertThrowsError(try ABIValue(amount + 1, type: .uint(bits: 160)))
        XCTAssertThrowsError(try ABIValue(expiration + 1, type: .uint(bits: 48)))
        XCTAssertEqual(try ERC20Encoder.encodeTransfer(to: address, tokens: 1).hexString,
                       "a9059cbb" + String(repeating: "0", count: 24) + String(repeating: "aa", count: 20)
                       + String(repeating: "0", count: 63) + "1")
    }
}

final class DerivationPathIndexTests: XCTestCase {
    /// Public BIP39 test vector.
    private let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"

    func testIndexRejectsValuesOutsideUInt32WithoutTrapping() {
        for value in [Int.min, -1, 0x1_0000_0000, Int.max] {
            for hardened in [false, true] {
                XCTAssertNil(DerivationPath.Index(value, hardened: hardened).derivationIndex)
            }
        }

        var index = DerivationPath.Index(0)
        index.value = -1
        XCTAssertNil(index.derivationIndex)
    }

    func testBoundaryIndicesPreserveTheirEncodedChildNumbers() {
        let cases: [(Int, Bool, UInt32)] = [
            (0, false, 0),
            (0, true, 0x80000000),
            (0x7fffffff, false, 0x7fffffff),
            (0x7fffffff, true, 0xffffffff),
            (0x80000000, false, 0x80000000),
            (0x80000000, true, 0x80000000),
            (0xffffffff, false, 0xffffffff),
            (0xffffffff, true, 0xffffffff)
        ]
        for (value, hardened, expected) in cases {
            let index = DerivationPath.Index(value, hardened: hardened)
            XCTAssertEqual(index.derivationIndex, expected)
            let parsed = DerivationPath("m/" + index.description)
            XCTAssertEqual(parsed?.indices.first?.derivationIndex, expected)
        }
    }

    func testPathParserRejectsNegativeAndUnrepresentableComponents() {
        let values = ["-1", String(Int.min), "4294967296", String(Int.max), "9223372036854775808"]
        for value in values {
            for suffix in ["", "'"] {
                XCTAssertNil(DerivationPath("m/\(value)\(suffix)/0"))
                XCTAssertNil(DerivationPath("m/44'/195'/0'/0/\(value)\(suffix)"))
            }
        }
    }

    func testWalletRejectsInvalidPathsAndPlaceholderIndicesWithoutFallback() throws {
        let wallet = try TLCore.Wallet(mnemonic: mnemonic, path: "m/44'/195'/0'/0/x")
        for index in [-1, 0x1_0000_0000, Int.max] {
            XCTAssertThrowsError(try wallet.getKey(at: index)) { error in
                guard case TLCore.Wallet.Error.invalidDerivationPath = error else {
                    return XCTFail("Unexpected error: \(error)")
                }
            }
        }

        for component in ["-1", "-1'", "4294967296", "4294967296'"] {
            wallet.path = "m/44'/195'/0'/0/" + component
            XCTAssertThrowsError(try wallet.getKey(at: 0)) { error in
                guard case TLCore.Wallet.Error.invalidDerivationPath = error else {
                    return XCTFail("Unexpected error: \(error)")
                }
            }
        }

        // Failed derivations must not alter the wallet's subsequent valid result.
        wallet.path = TLCore.Wallet.defaultPath
        XCTAssertEqual(try wallet.getKey(at: 0).privateKey.hexString,
                       "b5a4cea271ff424d7c31dc12a3e43e401df7a40d7412a15750f3f0b6b5449a28")
    }

    func testLegacyEncodedHardenedPathsPreserveDerivedKeys() throws {
        let paths = [
            ("m/44'/195'/2147483648'/0/0", "m/44'/195'/0'/0/0"),
            ("m/44'/195'/0'/0/2147483648", "m/44'/195'/0'/0/0'"),
            ("m/44'/195'/0'/0/4294967295", "m/44'/195'/0'/0/2147483647'"),
            ("m/44'/195'/0'/0/4294967295'", "m/44'/195'/0'/0/2147483647'")
        ]
        let wallet = try TLCore.Wallet(mnemonic: mnemonic)
        for (legacy, canonical) in paths {
            wallet.path = canonical
            let expected = try wallet.getKey(at: 0)
            wallet.path = legacy
            let actual = try wallet.getKey(at: 0)
            XCTAssertEqual(actual.privateKey, expected.privateKey)
            XCTAssertEqual(actual.publicKey, expected.publicKey)
            XCTAssertEqual(DerivationPath(legacy)?.description, legacy)
        }

        wallet.path = "m/44'/195'/0'/0/x"
        let placeholderKey = try wallet.getKey(at: 0xffffffff)
        wallet.path = "m/44'/195'/0'/0/2147483647'"
        XCTAssertEqual(placeholderKey.privateKey, try wallet.getKey(at: 0).privateKey)
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

    func testEncryptedKeyGenerationIsRejectedWithoutSideEffects() throws {
        XCTAssertThrowsError(try KeystoreKey(password: password, type: .encryptedKey)) { error in
            guard case EncryptError.generateKeyPairFail = error else {
                return XCTFail("Expected generateKeyPairFail, got \(error)")
            }
        }

        let store = try KeyStore(keyDirectory: keyDirectory)
        XCTAssertThrowsError(try store.createAccount(password: password, type: .encryptedKey)) { error in
            guard case EncryptError.generateKeyPairFail = error else {
                return XCTFail("Expected generateKeyPairFail, got \(error)")
            }
        }
        XCTAssertTrue(store.accounts.isEmpty)
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(at: keyDirectory, includingPropertiesForKeys: []).isEmpty)
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

    /// Invalid input must fail at the Swift API boundary with one stable error instead of reaching
    /// encryption or public-key derivation.
    func testInvalidPrivateKeyThrowsInsteadOfTrapping() {
        let curveOrder = Data([
            0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
            0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xfe,
            0xba, 0xae, 0xdc, 0xe6, 0xaf, 0x48, 0xa0, 0x3b,
            0xbf, 0xd2, 0x5e, 0x8c, 0xd0, 0x36, 0x41, 0x41,
        ])
        assertRejectsPrivateKey(Data(repeating: 1, count: 16))
        assertRejectsPrivateKey(Data(repeating: 0, count: 32))
        assertRejectsPrivateKey(curveOrder)
        assertRejectsPrivateKey(Data(repeating: 0xff, count: 32))
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

    /// A complete mnemonic payload is not a 32-byte private-key scalar.
    func testKeystoreKeyRejectsLongMnemonicPayload() throws {
        let payload = try XCTUnwrap(mnemonic.data(using: .ascii))
        XCTAssertGreaterThan(payload.count, 32)
        assertRejectsPrivateKey(payload)
    }

    /// Content heuristics must not reject a valid scalar solely because every byte is printable.
    func testKeystoreKeyAcceptsPrintableASCIIScalar() throws {
        let mnemonicPayload = try XCTUnwrap(mnemonic.data(using: .ascii))
        let privateKey = Data(mnemonicPayload.prefix(32))
        XCTAssertEqual(privateKey.count, 32)
        XCTAssertTrue(privateKey.allSatisfy { (0x20 ... 0x7e).contains($0) })
        XCTAssertTrue(EthereumCrypto.isValidPrivateKey(privateKey))
        XCTAssertEqual(try KeystoreKey(password: password, key: privateKey).type, .encryptedKey)
    }

    func testKeystoreKeyAcceptsScalarImmediatelyBelowCurveOrder() throws {
        let privateKey = Data([
            0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
            0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xfe,
            0xba, 0xae, 0xdc, 0xe6, 0xaf, 0x48, 0xa0, 0x3b,
            0xbf, 0xd2, 0x5e, 0x8c, 0xd0, 0x36, 0x41, 0x40,
        ])
        XCTAssertTrue(EthereumCrypto.isValidPrivateKey(privateKey))
        XCTAssertEqual(try KeystoreKey(password: password, key: privateKey).type, .encryptedKey)
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

// Expected ABI vectors below are independent handwritten words, not encoder output.
final class ABIv2RegressionTests: XCTestCase {
    private typealias Parameter = TLCore.ABIv2.Element.ParameterType

    private func word(_ value: UInt64) -> Data {
        var result = Data(repeating: 0, count: 32)
        for byte in 0..<8 {
            result[31 - byte] = UInt8((value >> (byte * 8)) & 0xff)
        }
        return result
    }

    private func words(_ values: [UInt64]) -> Data {
        return values.reduce(into: Data()) { $0.append(word($1)) }
    }

    private func rightPaddedWord(_ bytes: Data) -> Data {
        precondition(bytes.count <= 32)
        return bytes + Data(repeating: 0, count: 32 - bytes.count)
    }

    private func signedByteWord(_ value: Int8) -> Data {
        var result = Data(repeating: value < 0 ? 0xff : 0, count: 32)
        result[31] = UInt8(bitPattern: value)
        return result
    }

    private func parseRecord(_ json: String) throws -> TLCore.ABIv2.Element {
        return try JSONDecoder().decode(TLCore.ABIv2.Record.self, from: Data(json.utf8)).parse()
    }

    private func eventLog(data: Data, topics: [Data]) throws -> TLCore.EventLog {
        let object: [String: Any] = [
            "address": "0x1111111111111111111111111111111111111111",
            "blockHash": "0x" + String(repeating: "00", count: 32),
            "blockNumber": "0x1", "data": "0x" + data.hex,
            "logIndex": "0x0", "removed": "0x0",
            "topics": topics.map { "0x" + $0.hex },
            "transactionHash": "0x" + String(repeating: "00", count: 32),
            "transactionIndex": "0x0"
        ]
        let json = try JSONSerialization.data(withJSONObject: object)
        return try JSONDecoder().decode(TLCore.EventLog.self, from: json)
    }

    private func decodedUIntRows(_ value: AnyObject) throws -> [[BigUInt]] {
        try XCTUnwrap(value as? [AnyObject]).map { row in
            try XCTUnwrap(row as? [AnyObject]).map { try XCTUnwrap($0 as? BigUInt) }
        }
    }

    private func decodedBoolRows(_ value: AnyObject) throws -> [[Bool]] {
        try XCTUnwrap(value as? [AnyObject]).map { row in
            try XCTUnwrap(row as? [AnyObject]).map { try XCTUnwrap($0 as? Bool) }
        }
    }

    private func decodedStringRows(_ value: AnyObject) throws -> [[String]] {
        try XCTUnwrap(value as? [AnyObject]).map { row in
            try XCTUnwrap(row as? [AnyObject]).map { try XCTUnwrap($0 as? String) }
        }
    }

    func testTwoDynamicMatricesMatchBatchBalanceCheckAndBridgeToAppTypes() throws {
        let uintMatrix: Parameter = .array(type: .array(type: .uint(bits: 256), length: 0), length: 0)
        let boolMatrix: Parameter = .array(type: .array(type: .bool, length: 0), length: 0)
        // Each outer tail occupies 320 bytes. Inner offsets start immediately
        // after the respective outer length word, not at the entire payload.
        let expected = words([64, 384,
                              3, 96, 192, 224, 2, 1, 2, 0, 1, 3,
                              3, 96, 160, 256, 1, 1, 2, 0, 1, 0])
        let balances: [[BigUInt]] = [[1, 2], [], [3]]
        let flags = [[true], [false, true], []]
        let values: [AnyObject] = [balances as AnyObject, flags as AnyObject]
        XCTAssertEqual(TLCore.ABIv2Encoder.encode(types: [uintMatrix, boolMatrix], values: values), expected)
        let decoded = try XCTUnwrap(TLCore.ABIv2Decoder.decode(types: [uintMatrix, boolMatrix], data: expected))
        XCTAssertEqual(decoded.count, 2)
        XCTAssertEqual(try decodedUIntRows(decoded[0]), balances)
        XCTAssertEqual(try decodedBoolRows(decoded[1]), flags)
    }

    func testAllFourArrayDimensionKindsUseIndependentWordLayouts() throws {
        let fixedRows: [[BigUInt]] = [[1, 2], [3, 4]]
        let dynamicRows: [[BigUInt]] = [[1, 2], [3]]
        let cases: [(String, [[BigUInt]], Data)] = [
            ("uint256[2][2]", fixedRows, words([1, 2, 3, 4])),
            ("uint256[][2]", dynamicRows, words([32, 64, 160, 2, 1, 2, 1, 3])),
            ("uint256[2][]", fixedRows, words([32, 2, 1, 2, 3, 4])),
            ("uint256[][]", dynamicRows, words([32, 2, 64, 160, 2, 1, 2, 1, 3]))
        ]
        for (typeString, value, expected) in cases {
            let type = try TLCore.ABIv2TypeParser.parseTypeString(typeString)
            XCTAssertEqual(TLCore.ABIv2Encoder.encode(types: [type], values: [value as AnyObject]), expected, typeString)
            let decoded = try XCTUnwrap(TLCore.ABIv2Decoder.decode(types: [type], data: expected), typeString)
            XCTAssertEqual(try decodedUIntRows(try XCTUnwrap(decoded.first, typeString)), value, typeString)
        }
    }

    func testStringArrayWithThreeElementsDoesNotSkipFollowingArgument() throws {
        let strings: Parameter = .array(type: .string, length: 0)
        let tail = words([3, 96, 160, 224, 1])
            + rightPaddedWord(Data("a".utf8))
            + word(2) + rightPaddedWord(Data("bb".utf8))
            + word(3) + rightPaddedWord(Data("ccc".utf8))
        let expected = words([64, 9]) + tail
        let types: [Parameter] = [strings, .uint(bits: 256)]
        XCTAssertEqual(TLCore.ABIv2Encoder.encode(types: types, values: [["a", "bb", "ccc"] as AnyObject, BigUInt(9) as AnyObject]), expected)
        let decoded = try XCTUnwrap(TLCore.ABIv2Decoder.decode(types: types, data: expected))
        XCTAssertEqual(decoded[0] as? [String], ["a", "bb", "ccc"])
        XCTAssertEqual(decoded[1] as? BigUInt, BigUInt(9))

        // The old public spelling remains callable. Its consumed count must be
        // a relative head width even when decoding starts at a nonzero pointer.
        let nonzeroPointerData = words([7, 96, 9]) + tail
        let single = TLCore.ABIv2Decoder.decodeSignleType(type: strings, data: nonzeroPointerData, pointer: 32, allowLegacyBytes32: false, minimumTail: 96)
        XCTAssertEqual(single.value as? [String], ["a", "bb", "ccc"])
        XCTAssertEqual(single.bytesConsumed, UInt64(32))
        let next = TLCore.ABIv2Decoder.decodeSignleType(type: .uint(bits: 256), data: nonzeroPointerData, pointer: 64, allowLegacyBytes32: false, minimumTail: 96)
        XCTAssertEqual(next.value as? BigUInt, BigUInt(9))
        XCTAssertEqual(next.bytesConsumed, UInt64(32))
    }

    func testThreeStringArrayRowsUseOffsetsRelativeToEachOwnLengthWord() throws {
        let type: Parameter = .array(type: .array(type: .string, length: 0), length: 0)
        let value = [["a", "bb"], ["ccc"], []]
        // Outer row tails occupy 224, 128 and 32 bytes respectively. The
        // third row is empty, while the first two have different strings.
        let expected = words([32, 3, 96, 320, 448, 2, 64, 128, 1])
            + rightPaddedWord(Data("a".utf8))
            + word(2) + rightPaddedWord(Data("bb".utf8))
            + words([1, 32, 3]) + rightPaddedWord(Data("ccc".utf8))
            + word(0)
        XCTAssertEqual(TLCore.ABIv2Encoder.encode(types: [type], values: [value as AnyObject]), expected)
        let decoded = try XCTUnwrap(TLCore.ABIv2Decoder.decode(types: [type], data: expected))
        XCTAssertEqual(try decodedStringRows(decoded[0]), value)
    }

    func testDynamicTupleDoesNotAdvancePastFollowingInteger() throws {
        let tupleType: Parameter = .tuple(types: [.uint(bits: 256), .string])
        let types: [Parameter] = [tupleType, .uint(bits: 256)]
        let tuple: [AnyObject] = [BigUInt(7) as AnyObject, "hi" as AnyObject]
        let expected = words([64, 9, 7, 64, 2]) + rightPaddedWord(Data("hi".utf8))
        XCTAssertEqual(TLCore.ABIv2Encoder.encode(types: types, values: [tuple as AnyObject, BigUInt(9) as AnyObject]), expected)
        let decoded = try XCTUnwrap(TLCore.ABIv2Decoder.decode(types: types, data: expected))
        let decodedTuple = try XCTUnwrap(decoded[0] as? [AnyObject])
        XCTAssertEqual(decodedTuple[0] as? BigUInt, BigUInt(7))
        XCTAssertEqual(decodedTuple[1] as? String, "hi")
        XCTAssertEqual(decoded[1] as? BigUInt, BigUInt(9))
    }

    func testStaticTupleArrayContributesItsFullWidthBeforeDynamicString() throws {
        let arrayType: Parameter = .array(type: .tuple(types: [.uint(bits: 256), .bool]), length: 2)
        let types: [Parameter] = [arrayType, .string]
        let rows: [[AnyObject]] = [[BigUInt(1) as AnyObject, true as AnyObject],
                                  [BigUInt(2) as AnyObject, false as AnyObject]]
        // Two 64-byte static tuples and one 32-byte offset form a 160-byte head.
        let expected = words([1, 1, 2, 0, 160, 2]) + rightPaddedWord(Data("ok".utf8))
        XCTAssertEqual(TLCore.ABIv2Encoder.encode(types: types, values: [rows as AnyObject, "ok" as AnyObject]), expected)
        let decoded = try XCTUnwrap(TLCore.ABIv2Decoder.decode(types: types, data: expected))
        let decodedRows = try XCTUnwrap(decoded[0] as? [[AnyObject]])
        XCTAssertEqual(decodedRows.count, 2)
        XCTAssertEqual(decodedRows[0][0] as? BigUInt, BigUInt(1))
        XCTAssertEqual(decodedRows[0][1] as? Bool, true)
        XCTAssertEqual(decodedRows[1][0] as? BigUInt, BigUInt(2))
        XCTAssertEqual(decodedRows[1][1] as? Bool, false)
        XCTAssertEqual(decoded[1] as? String, "ok")
    }

    func testTupleWithDynamicArrayUsesTupleRelativeOffsets() throws {
        let type: Parameter = .tuple(types: [.uint(bits: 256), .array(type: .string, length: 0)])
        let expected = words([32, 7, 64, 2, 64, 128, 1])
            + rightPaddedWord(Data("a".utf8))
            + word(2) + rightPaddedWord(Data("bb".utf8))
        let tuple: [AnyObject] = [BigUInt(7) as AnyObject, ["a", "bb"] as AnyObject]
        XCTAssertEqual(TLCore.ABIv2Encoder.encode(types: [type], values: [tuple as AnyObject]), expected)
        let decoded = try XCTUnwrap(TLCore.ABIv2Decoder.decode(types: [type], data: expected))
        let result = try XCTUnwrap(decoded[0] as? [AnyObject])
        XCTAssertEqual(result[0] as? BigUInt, BigUInt(7))
        XCTAssertEqual(result[1] as? [String], ["a", "bb"])
    }

    func testEmptyDynamicArrayAndStringHaveLengthWords() throws {
        let types: [Parameter] = [.array(type: .uint(bits: 256), length: 0), .string]
        let expected = words([64, 96, 0, 0])
        let empty: [BigUInt] = []
        XCTAssertEqual(TLCore.ABIv2Encoder.encode(types: types, values: [empty as AnyObject, "" as AnyObject]), expected)
        let decoded = try XCTUnwrap(TLCore.ABIv2Decoder.decode(types: types, data: expected))
        XCTAssertEqual(decoded[0] as? [BigUInt], [])
        XCTAssertEqual(decoded[1] as? String, "")
    }

    func testJSONTupleComponentsSurviveEveryArrayDimensionAndNestedTuple() throws {
        let json = """
        {"type":"function","name":"f","stateMutability":"view",
         "inputs":[{"name":"items","type":"tuple[][2][]","components":[
           {"name":"owner","type":"address"},
           {"name":"flags","type":"tuple[]","components":[{"name":"n","type":"uint256"},{"name":"ok","type":"bool"}]}]}],
         "outputs":[{"name":"items","type":"tuple[][2][]","components":[
           {"name":"owner","type":"address"},
           {"name":"flags","type":"tuple[]","components":[{"name":"n","type":"uint256"},{"name":"ok","type":"bool"}]}]}]}
        """
        guard case let .function(function) = try parseRecord(json) else { return XCTFail("Expected function") }
        let leaf: Parameter = .tuple(types: [.address, .array(type: .tuple(types: [.uint(bits: 256), .bool]), length: 0)])
        let expected: Parameter = .array(type: .array(type: .array(type: leaf, length: 0), length: 2), length: 0)
        XCTAssertEqual(function.inputs.first?.type, expected)
        XCTAssertEqual(function.outputs.first?.type, expected)
        XCTAssertEqual(expected.abiRepresentation, "(address,(uint256,bool)[])[][2][]")
        XCTAssertEqual(function.signature, "f((address,(uint256,bool)[])[][2][])")
        let canonical = Data("f((address,(uint256,bool)[])[][2][])".utf8)
        XCTAssertEqual(function.methodEncoding, Data(EthereumCrypto.hash(canonical).prefix(4)))
        XCTAssertEqual(try TLCore.ABIv2TypeParser.parseTypeString("(address,(uint256,bool)[])[][2][]"), expected)
    }

    func testFunctionSelectorMatchesKnownERC20VectorAndMethodStringStaysFullHash() throws {
        let json = """
        {"type":"function","name":"transfer","stateMutability":"nonpayable",
         "inputs":[{"name":"to","type":"address"},{"name":"value","type":"uint256"}],"outputs":[]}
        """
        guard case let .function(function) = try parseRecord(json) else { return XCTFail("Expected function") }
        XCTAssertEqual(function.signature, "transfer(address,uint256)")
        XCTAssertEqual(function.methodEncoding, Data([0xa9, 0x05, 0x9c, 0xbb]))
        XCTAssertEqual(function.methodString, "a9059cbb2ab09eb219583f4a59a5d0623ade346d962bcd4e46b11da047c9049b")
    }

    func testModernJSONMutabilityDoesNotRequireLegacyPayable() throws {
        for (mutability, isConstant, isPayable) in [("view", true, false), ("pure", true, false), ("nonpayable", false, false), ("payable", false, true)] {
            let json = "{\"type\":\"function\",\"name\":\"f\",\"stateMutability\":\"\(mutability)\",\"inputs\":[],\"outputs\":[]}"
            guard case let .function(function) = try parseRecord(json) else { return XCTFail("Expected function") }
            XCTAssertEqual(function.constant, isConstant)
            XCTAssertEqual(function.payable, isPayable)
        }
        guard case let .fallback(fallback) = try parseRecord("{\"type\":\"fallback\",\"stateMutability\":\"nonpayable\"}") else { return XCTFail("Expected fallback") }
        XCTAssertFalse(fallback.payable)
        guard case let .constructor(constructor) = try parseRecord("{\"type\":\"constructor\",\"stateMutability\":\"payable\",\"inputs\":[]}") else { return XCTFail("Expected constructor") }
        XCTAssertTrue(constructor.payable)
        XCTAssertThrowsError(try parseRecord("{\"type\":\"function\",\"name\":\"f\",\"inputs\":[{\"type\":\"tuple[]\"}],\"outputs\":[]}"))
        XCTAssertThrowsError(try TLCore.ABIv2TypeParser.parseTypeString("uint7"))
        XCTAssertThrowsError(try TLCore.ABIv2TypeParser.parseTypeString("bytes33"))
        XCTAssertThrowsError(try TLCore.ABIv2TypeParser.parseTypeString("uint256[00]"))
        XCTAssertThrowsError(try TLCore.ABIv2TypeParser.parseTypeString("uint256garbage"))
    }

    func testReceiveAndCustomErrorJSONSupportIndependentRevertPayload() throws {
        guard case let .receive(receive) = try parseRecord("{\"type\":\"receive\",\"stateMutability\":\"payable\"}") else {
            return XCTFail("Expected receive")
        }
        XCTAssertTrue(receive.payable)
        let json = """
        {"type":"error","name":"Error","inputs":[{"name":"reason","type":"string"}]}
        """
        let element = try parseRecord(json)
        guard case let .error(customError) = element else { return XCTFail("Expected custom error") }
        let selector = Data([0x08, 0xc3, 0x79, 0xa0])
        let argumentBytes = words([32, 2]) + rightPaddedWord(Data("no".utf8))
        let payload = selector + argumentBytes
        XCTAssertEqual(customError.signature, "Error(string)")
        XCTAssertEqual(customError.methodEncoding, selector)
        XCTAssertEqual(element.encodeParameters(["no" as AnyObject]), payload)
        let decoded = try XCTUnwrap(element.decodeInputData(payload))
        XCTAssertEqual(decoded["0"] as? String, "no")
        XCTAssertEqual(decoded["reason"] as? String, "no")
        XCTAssertNil(element.decodeInputData(Data([0, 0, 0, 0]) + argumentBytes))
    }

    func testIntegerBoundsAndSignedExtensionMatchWords() throws {
        let types: [Parameter] = [.uint(bits: 8), .int(bits: 8), .int(bits: 8)]
        let expected = word(255) + signedByteWord(-128) + word(127)
        XCTAssertEqual(TLCore.ABIv2Encoder.encode(types: types, values: [BigUInt(255) as AnyObject, BigInt(-128) as AnyObject, BigInt(127) as AnyObject]), expected)
        let decoded = try XCTUnwrap(TLCore.ABIv2Decoder.decode(types: types, data: expected))
        XCTAssertEqual(decoded[0] as? BigUInt, BigUInt(255))
        XCTAssertEqual(decoded[1] as? BigInt, BigInt(-128))
        XCTAssertEqual(decoded[2] as? BigInt, BigInt(127))
        XCTAssertNil(TLCore.ABIv2Encoder.encodeSingleType(type: .uint(bits: 8), value: BigUInt(256) as AnyObject))
        XCTAssertNil(TLCore.ABIv2Encoder.encodeSingleType(type: .int(bits: 8), value: BigInt(128) as AnyObject))
        XCTAssertNil(TLCore.ABIv2Encoder.encodeSingleType(type: .int(bits: 8), value: BigInt(-129) as AnyObject))
        for negative in [Int(-1) as AnyObject, BigInt(-1) as AnyObject, "-1" as AnyObject] {
            XCTAssertNil(TLCore.ABIv2Encoder.encodeSingleType(type: .uint(bits: 256), value: negative))
        }
        XCTAssertNil(TLCore.ABIv2Decoder.decode(types: [.uint(bits: 8)], data: word(256)))
        XCTAssertNil(TLCore.ABIv2Decoder.decode(types: [.int(bits: 8)], data: word(128)))
        XCTAssertNil(TLCore.ABIv2Decoder.decode(types: [.bool], data: word(2)))

        let maximumUnsigned = (BigUInt(1) << 256) - 1
        let maximumSigned = (BigInt(1) << 255) - 1
        let minimumSigned = -(BigInt(1) << 255)
        let allOnes = Data(repeating: 0xff, count: 32)
        let signedMaximumWord = Data([0x7f]) + Data(repeating: 0xff, count: 31)
        let signedMinimumWord = Data([0x80]) + Data(repeating: 0, count: 31)
        XCTAssertEqual(TLCore.ABIv2Encoder.encodeSingleType(type: .uint(bits: 256), value: maximumUnsigned as AnyObject), allOnes)
        XCTAssertEqual(TLCore.ABIv2Encoder.encodeSingleType(type: .int(bits: 256), value: maximumSigned as AnyObject), signedMaximumWord)
        XCTAssertEqual(TLCore.ABIv2Encoder.encodeSingleType(type: .int(bits: 256), value: minimumSigned as AnyObject), signedMinimumWord)
        XCTAssertNil(TLCore.ABIv2Encoder.encodeSingleType(type: .uint(bits: 256), value: (maximumUnsigned + 1) as AnyObject))
        XCTAssertNil(TLCore.ABIv2Encoder.encodeSingleType(type: .int(bits: 256), value: (maximumSigned + 1) as AnyObject))
        XCTAssertNil(TLCore.ABIv2Encoder.encodeSingleType(type: .int(bits: 256), value: (minimumSigned - 1) as AnyObject))
    }

    func testEmptyOrSignOnlyIntegerStringsAreRejectedInsteadOfBecomingZero() {
        // BigInt 3.x accepts some empty digit sequences as zero; ABI values
        // must contain at least one actual digit after a sign or hex prefix.
        for value in ["", "0x", "+", "-", "+0x"] {
            XCTAssertNil(TLCore.ABIv2Encoder.convertToBigUInt(value as AnyObject), value)
            XCTAssertNil(TLCore.ABIv2Encoder.convertToBigInt(value as AnyObject), value)
            XCTAssertNil(TLCore.ABIv2Encoder.encodeSingleType(type: .uint(bits: 256), value: value as AnyObject), value)
            XCTAssertNil(TLCore.ABIv2Encoder.encodeSingleType(type: .int(bits: 256), value: value as AnyObject), value)
        }
    }

    func testStringBeginningWithHexPrefixIsUTF8AndFunctionIsLeftAligned() throws {
        let expectedString = words([32, 4]) + rightPaddedWord(Data("0x41".utf8))
        XCTAssertEqual(TLCore.ABIv2Encoder.encode(types: [.string], values: ["0x41" as AnyObject]), expectedString)
        let string = try XCTUnwrap(TLCore.ABIv2Decoder.decode(types: [.string], data: expectedString))
        XCTAssertEqual(string[0] as? String, "0x41")
        let function = Data((1...24).map { UInt8($0) })
        let expectedFunction = function + Data(repeating: 0, count: 8)
        XCTAssertEqual(TLCore.ABIv2Encoder.encodeSingleType(type: .function, value: function as AnyObject), expectedFunction)
        let decoded = try XCTUnwrap(TLCore.ABIv2Decoder.decode(types: [.function], data: expectedFunction))
        XCTAssertEqual(decoded[0] as? Data, function)
        XCTAssertNil(TLCore.ABIv2Encoder.encodeSingleType(type: .function, value: Data(repeating: 1, count: 23) as AnyObject))
        XCTAssertNil(TLCore.ABIv2Encoder.encodeSingleType(type: .bytes(length: 2), value: Data([1, 2, 3]) as AnyObject))
    }

    func testAddressDecodesAsTwentyByteWeb3AddressAndAcceptsExplicitTRONPrefix() throws {
        let address = Data(repeating: 0x11, count: 20)
        let expected = Data(repeating: 0, count: 12) + address
        for raw in [address, Data([0x41]) + address] {
            XCTAssertEqual(TLCore.ABIv2Encoder.encodeSingleType(type: .address, value: raw as AnyObject), expected)
        }
        let decoded = try XCTUnwrap(TLCore.ABIv2Decoder.decode(types: [.address], data: expected))
        let result = try XCTUnwrap(decoded[0] as? TLCore.Web3Address)
        XCTAssertEqual(result.addressData, address)
        XCTAssertEqual(result.addressData.count, 20)
        XCTAssertNil(TLCore.ABIv2Encoder.encodeSingleType(type: .address, value: Data(repeating: 1, count: 19) as AnyObject))
        XCTAssertNil(TLCore.ABIv2Encoder.encodeSingleType(type: .address, value: (Data([0x42]) + address) as AnyObject))
    }

    func testLegacyTokenBytes32StringCompatibilityIsRestrictedToOneTopLevelString() throws {
        let tokenWord = rightPaddedWord(Data("USDT".utf8))
        let result = try XCTUnwrap(TLCore.ABIv2Decoder.decode(types: [.string], data: tokenWord))
        XCTAssertEqual(result[0] as? String, "USDT")
        XCTAssertNil(TLCore.ABIv2Decoder.decode(types: [.string, .uint(bits: 256)], data: tokenWord + word(7)))
        XCTAssertNil(TLCore.ABIv2Decoder.decode(types: [.array(type: .string, length: 0)], data: words([32, 1]) + tokenWord))
        XCTAssertNil(TLCore.ABIv2Decoder.decode(types: [.dynamicBytes], data: tokenWord))
    }

    func testInvalidArrayElementsAndTupleArityFailAsAWhole() {
        let array: Parameter = .array(type: .uint(bits: 256), length: 0)
        let invalid: [AnyObject] = [BigUInt(1) as AnyObject, "not-a-number" as AnyObject, BigUInt(3) as AnyObject]
        XCTAssertNil(TLCore.ABIv2Encoder.encode(types: [array], values: [invalid as AnyObject]))
        let tuple: Parameter = .tuple(types: [.uint(bits: 256), .bool])
        XCTAssertNil(TLCore.ABIv2Encoder.encode(types: [tuple], values: [[BigUInt(1)] as AnyObject]))
        XCTAssertNil(TLCore.ABIv2Encoder.encode(types: [tuple], values: [[BigUInt(1) as AnyObject, true as AnyObject, false as AnyObject] as AnyObject]))
        XCTAssertNil(TLCore.ABIv2Encoder.encode(types: [.array(type: .uint(bits: 256), length: 2)], values: [[BigUInt(1)] as AnyObject]))
        // bool[]: the second word is invalid. Returning only [true] is forbidden.
        XCTAssertNil(TLCore.ABIv2Decoder.decode(types: [.array(type: .bool, length: 0)], data: words([32, 2, 1, 2])))
        // string[]: valid first element followed by an out-of-bounds pointer.
        let badStrings = words([32, 2, 64, 999_968, 1]) + rightPaddedWord(Data("a".utf8))
        XCTAssertNil(TLCore.ABIv2Decoder.decode(types: [.array(type: .string, length: 0)], data: badStrings))
    }

    func testMalformedOffsetsLengthsAndTruncationReturnNil() {
        let type: Parameter = .array(type: .uint(bits: 256), length: 0)
        XCTAssertNil(TLCore.ABIv2Decoder.decode(types: [type], data: words([0, 0])))
        XCTAssertNil(TLCore.ABIv2Decoder.decode(types: [type], data: words([33, 0, 0])))
        XCTAssertNil(TLCore.ABIv2Decoder.decode(types: [type], data: words([96, 0])))
        XCTAssertNil(TLCore.ABIv2Decoder.decode(types: [type], data: words([32, 2, 1])))
        XCTAssertNil(TLCore.ABIv2Decoder.decode(types: [type], data: word(32) + Data(repeating: 0xff, count: 32)))
        XCTAssertNil(TLCore.ABIv2Decoder.decode(types: [.uint(bits: 256)], data: Data(repeating: 0, count: 31)))
        XCTAssertNil(TLCore.ABIv2Decoder.decode(types: [.dynamicBytes], data: words([32, 64 * 1024 * 1024 + 1])))
        let string = words([32, 1]) + rightPaddedWord(Data("a".utf8))
        XCTAssertNil(TLCore.ABIv2Decoder.decode(types: [.string], data: Data(string.dropLast())))
        let single = TLCore.ABIv2Decoder.decodeSignleType(type: .uint(bits: 256), data: word(1), pointer: UInt64.max)
        XCTAssertNil(single.value)
        XCTAssertNil(single.bytesConsumed)
    }

    func testDataSliceWithNonzeroStartIndexIsDecodedFromItsOwnBeginning() throws {
        let type: Parameter = .array(type: .uint(bits: 256), length: 0)
        let expected = words([32, 2, 5, 6])
        let framed = Data([0xff]) + expected
        let slice = framed.dropFirst()
        XCTAssertEqual(slice.startIndex, 1)
        let decoded = try XCTUnwrap(TLCore.ABIv2Decoder.decode(types: [type], data: slice))
        XCTAssertEqual(decoded[0] as? [BigUInt], [5, 6])
        let bytes = (Data([0xff]) + Data([0xaa, 0xbb])).dropFirst()
        XCTAssertEqual(TLCore.ABIv2Encoder.encodeSingleType(type: .bytes(length: 2), value: bytes as AnyObject), rightPaddedWord(Data([0xaa, 0xbb])))
    }

    func testSharedEmptyTupleArraysCannotBypassEncoderOrDecoderNodeBudget() {
        var type: Parameter = .tuple(types: [])
        var value = [AnyObject]() as AnyObject
        // Only three 100-element containers are allocated here. Sharing the
        // child object produces over one million logical nodes, zero ABI bytes.
        for _ in 0..<3 {
            type = .array(type: type, length: 100)
            value = Array(repeating: value, count: 100) as AnyObject
        }
        XCTAssertNil(TLCore.ABIv2Encoder.encode(types: [type], values: [value]))
        XCTAssertNil(TLCore.ABIv2Decoder.decode(types: [type], data: Data()))
    }

    func testSixtyThreeFixedArrayLevelsAroundEmptyTupleHaveConsistentDepthAccounting() throws {
        var type: Parameter = .tuple(types: [])
        var value = [AnyObject]() as AnyObject
        for _ in 0..<63 {
            type = .array(type: type, length: 1)
            value = [value] as AnyObject
        }
        XCTAssertEqual(TLCore.ABIv2Encoder.encode(types: [type], values: [value]), Data())
        let decoded = try XCTUnwrap(TLCore.ABIv2Decoder.decode(types: [type], data: Data()))
        var nested = try XCTUnwrap(decoded.first)
        for _ in 0..<63 {
            let array = try XCTUnwrap(nested as? [AnyObject])
            XCTAssertEqual(array.count, 1)
            nested = try XCTUnwrap(array.first)
        }
        XCTAssertTrue(try XCTUnwrap(nested as? [AnyObject]).isEmpty)
    }

    func testInvalidSchemaAndInputCannotUseMetadataFallback() throws {
        let invalidRecords = [
            "{\"type\":\"function\",\"inputs\":[]}",
            "{\"type\":\"event\",\"name\":\"\",\"inputs\":[]}",
            "{\"type\":\"error\",\"inputs\":[]}",
            "{\"type\":\"function\",\"name\":\"f\",\"stateMutability\":\"unknown\"}",
            "{\"type\":\"constructor\",\"stateMutability\":\"view\"}",
            "{\"type\":\"fallback\",\"stateMutability\":\"pure\"}",
            "{\"type\":\"receive\",\"stateMutability\":\"nonpayable\"}"
        ]
        for json in invalidRecords { XCTAssertThrowsError(try parseRecord(json)) }
        let json = """
        {"type":"function","name":"echo","stateMutability":"view",
         "inputs":[{"name":"value","type":"string"}],
         "outputs":[{"name":"value","type":"string"}]}
        """
        let element = try parseRecord(json)
        let tokenWord = rightPaddedWord(Data("USDT".utf8))
        XCTAssertNil(element.decodeInputData(tokenWord))
        XCTAssertNil(element.decodeInputData(Data()))
        XCTAssertNil(element.decodeReturnData(Data()))
        XCTAssertEqual(element.decodeReturnData(tokenWord)?["value"] as? String, "USDT")
    }

    func testTypedNegativeZeroFromBigIntThreeIsNormalized() throws {
        let negativeZero = try XCTUnwrap(BigInt("-0"))
        XCTAssertEqual(TLCore.ABIv2Encoder.convertToBigUInt(negativeZero as AnyObject), BigUInt(0))
        XCTAssertEqual(TLCore.ABIv2Encoder.encodeSingleType(type: .int(bits: 256), value: negativeZero as AnyObject), word(0))
        XCTAssertEqual(TLCore.ABIv2Encoder.encodeSingleType(type: .uint(bits: 256), value: negativeZero as AnyObject), word(0))
    }

    func testDepthAndDeclaredElementLimitsRejectSmallAdversarialInputs() {
        var deeplyNested: Parameter = .uint(bits: 256)
        for _ in 0..<80 { deeplyNested = .array(type: deeplyNested, length: 1) }
        XCTAssertNil(TLCore.ABIv2Decoder.decode(types: [deeplyNested], data: word(1)))
        XCTAssertThrowsError(try TLCore.ABIv2TypeParser.parseTypeString("uint256" + String(repeating: "[1]", count: 80)))
        let zeroWidthElements: Parameter = .array(type: .tuple(types: []), length: 0)
        // Zero-width tuples prevent payload length from serving as a node bound.
        XCTAssertNil(TLCore.ABIv2Decoder.decode(types: [zeroWidthElements], data: words([32, 1_000_001])))
        let impossibleStaticArray: Parameter = .array(type: .uint(bits: 256), length: UInt64.max)
        XCTAssertNil(TLCore.ABIv2Decoder.decode(types: [impossibleStaticArray], data: word(1)))
    }

    func testAnonymousEventDoesNotRequireSignatureTopic() throws {
        let json = """
        {"type":"event","name":"Note","anonymous":true,"inputs":[{"name":"n","type":"uint256","indexed":false}]}
        """
        guard case let .event(event) = try parseRecord(json) else { return XCTFail("Expected event") }
        let log = try eventLog(data: word(7), topics: [])
        let result = try XCTUnwrap(TLCore.ABIv2Decoder.decodeLog(event: event, eventLog: log))
        XCTAssertEqual(result["0"] as? BigUInt, BigUInt(7))
        XCTAssertEqual(result["n"] as? BigUInt, BigUInt(7))
        let extraTopic = try eventLog(data: word(7), topics: [word(1)])
        XCTAssertNil(TLCore.ABIv2Decoder.decodeLog(event: event, eventLog: extraTopic))
    }

    func testIndexedSingleWordTupleRemainsOpaqueTopicHash() throws {
        let json = """
        {"type":"event","name":"Seen","anonymous":false,"inputs":[
         {"name":"item","type":"tuple","indexed":true,"components":[{"name":"n","type":"uint256"}]},
         {"name":"count","type":"uint256","indexed":false}]}
        """
        guard case let .event(event) = try parseRecord(json) else { return XCTFail("Expected event") }
        XCTAssertEqual(event.signature, "Seen((uint256),uint256)")
        let suppliedHash = Data(repeating: 0x11, count: 32)
        let log = try eventLog(data: word(9), topics: [event.topic, suppliedHash])
        let result = try XCTUnwrap(TLCore.ABIv2Decoder.decodeLog(event: event, eventLog: log))
        XCTAssertEqual(result["item"] as? Data, suppliedHash)
        XCTAssertEqual(result["0"] as? Data, suppliedHash)
        XCTAssertEqual(result["count"] as? BigUInt, BigUInt(9))
        let missingTopics = try eventLog(data: word(9), topics: [])
        XCTAssertNil(TLCore.ABIv2Decoder.decodeLog(event: event, eventLog: missingTopics))
        let shortTopic = try eventLog(data: word(9), topics: [event.topic, Data([1])])
        XCTAssertNil(TLCore.ABIv2Decoder.decodeLog(event: event, eventLog: shortTopic))
    }
}

// Append in the same Tests.swift file as ABIv2RegressionTests so its private
// word/words/rightPaddedWord helpers are available. No test has been executed.
extension ABIv2RegressionTests {
    func testEveryIntegerWidthHasCorrectBoundaryWordsAndRejectsOverflow() throws {
        for byteWidth in 1...32 {
            let bits = UInt64(byteWidth * 8)
            let unsignedType: Parameter = .uint(bits: bits)
            let signedType: Parameter = .int(bits: bits)
            let unsignedMaximum = (BigUInt(1) << Int(bits)) - 1
            let signedMaximum = (BigInt(1) << Int(bits - 1)) - 1
            let signedMinimum = -(BigInt(1) << Int(bits - 1))

            // Expected bytes describe the ABI bit pattern directly. They do
            // not serialize the expected BigInt values or call the encoder.
            let unsignedMaximumWord = Data(repeating: 0, count: 32 - byteWidth)
                + Data(repeating: 0xff, count: byteWidth)
            let signedMaximumWord = Data(repeating: 0, count: 32 - byteWidth)
                + Data([0x7f]) + Data(repeating: 0xff, count: byteWidth - 1)
            let signedMinimumWord = Data(repeating: 0xff, count: 32 - byteWidth)
                + Data([0x80]) + Data(repeating: 0, count: byteWidth - 1)

            XCTAssertEqual(TLCore.ABIv2Encoder.encodeSingleType(type: unsignedType, value: BigUInt(0) as AnyObject), word(0), "uint\(bits) minimum")
            XCTAssertEqual(TLCore.ABIv2Encoder.encodeSingleType(type: unsignedType, value: unsignedMaximum as AnyObject), unsignedMaximumWord, "uint\(bits) maximum")
            XCTAssertEqual(TLCore.ABIv2Encoder.encodeSingleType(type: signedType, value: signedMinimum as AnyObject), signedMinimumWord, "int\(bits) minimum")
            XCTAssertEqual(TLCore.ABIv2Encoder.encodeSingleType(type: signedType, value: signedMaximum as AnyObject), signedMaximumWord, "int\(bits) maximum")

            let unsignedDecoded = try XCTUnwrap(TLCore.ABIv2Decoder.decode(types: [unsignedType, unsignedType], data: word(0) + unsignedMaximumWord))
            XCTAssertEqual(unsignedDecoded[0] as? BigUInt, BigUInt(0), "uint\(bits) minimum")
            XCTAssertEqual(unsignedDecoded[1] as? BigUInt, unsignedMaximum, "uint\(bits) maximum")
            let signedDecoded = try XCTUnwrap(TLCore.ABIv2Decoder.decode(types: [signedType, signedType], data: signedMinimumWord + signedMaximumWord))
            XCTAssertEqual(signedDecoded[0] as? BigInt, signedMinimum, "int\(bits) minimum")
            XCTAssertEqual(signedDecoded[1] as? BigInt, signedMaximum, "int\(bits) maximum")

            XCTAssertNil(TLCore.ABIv2Encoder.encodeSingleType(type: unsignedType, value: BigInt(-1) as AnyObject), "uint\(bits) negative")
            XCTAssertNil(TLCore.ABIv2Encoder.encodeSingleType(type: unsignedType, value: (unsignedMaximum + 1) as AnyObject), "uint\(bits) overflow")
            XCTAssertNil(TLCore.ABIv2Encoder.encodeSingleType(type: signedType, value: (signedMinimum - 1) as AnyObject), "int\(bits) underflow")
            XCTAssertNil(TLCore.ABIv2Encoder.encodeSingleType(type: signedType, value: (signedMaximum + 1) as AnyObject), "int\(bits) overflow")

            if byteWidth < 32 {
                // Wider nonzero unsigned bits and inconsistent signed extension
                // must not be silently reduced modulo the declared bit width.
                let unsignedOverflowWord = Data(repeating: 0, count: 31 - byteWidth)
                    + Data([1]) + Data(repeating: 0, count: byteWidth)
                let signedOverflowWord = Data(repeating: 0, count: 32 - byteWidth)
                    + Data([0x80]) + Data(repeating: 0, count: byteWidth - 1)
                let signedUnderflowWord = Data(repeating: 0xff, count: 32 - byteWidth)
                    + Data([0x7f]) + Data(repeating: 0xff, count: byteWidth - 1)
                XCTAssertNil(TLCore.ABIv2Decoder.decode(types: [unsignedType], data: unsignedOverflowWord), "uint\(bits) overflow word")
                XCTAssertNil(TLCore.ABIv2Decoder.decode(types: [signedType], data: signedOverflowWord), "int\(bits) overflow word")
                XCTAssertNil(TLCore.ABIv2Decoder.decode(types: [signedType], data: signedUnderflowWord), "int\(bits) underflow word")
            }
        }
    }

    func testEveryFixedBytesWidthUsesItsDeclaredPrefixAndOneWord() throws {
        for length in 1...32 {
            let type: Parameter = .bytes(length: UInt64(length))
            let value = Data((1...length).map { UInt8($0) })
            let expected = value + Data(repeating: 0, count: 32 - length)
            XCTAssertEqual(TLCore.ABIv2Encoder.encodeSingleType(type: type, value: value as AnyObject), expected, "bytes\(length)")
            let decoded = try XCTUnwrap(TLCore.ABIv2Decoder.decode(types: [type], data: expected))
            XCTAssertEqual(decoded[0] as? Data, value, "bytes\(length)")
            XCTAssertNil(TLCore.ABIv2Encoder.encodeSingleType(type: type, value: Data(repeating: 1, count: length + 1) as AnyObject), "bytes\(length) too long")
        }
    }

    func testMultibyteUTF8StringPreservesEmbeddedNULAndUsesByteLength() throws {
        let value = "钱包💎\u{0}X"
        let expectedUTF8 = Data([0xe9, 0x92, 0xb1, 0xe5, 0x8c, 0x85,
                                 0xf0, 0x9f, 0x92, 0x8e, 0x00, 0x58])
        let expected = words([32, 12]) + rightPaddedWord(expectedUTF8)
        XCTAssertEqual(TLCore.ABIv2Encoder.encode(types: [.string], values: [value as AnyObject]), expected)
        let decoded = try XCTUnwrap(TLCore.ABIv2Decoder.decode(types: [.string], data: expected))
        XCTAssertEqual(decoded[0] as? String, value)
        XCTAssertEqual((decoded[0] as? String)?.utf8.count, 12)
    }

    func testDynamicBytesAtWordBoundariesUseIndependentLengthAndPadding() throws {
        for length in [0, 31, 32, 33, 64] {
            let value = Data(repeating: 0xa5, count: length)
            let padding = (32 - length % 32) % 32
            let body = word(UInt64(length)) + value + Data(repeating: 0, count: padding)
            let expected = word(32) + body
            XCTAssertEqual(TLCore.ABIv2Encoder.encodeSingleType(type: .dynamicBytes, value: value as AnyObject), body, "length \(length)")
            XCTAssertEqual(TLCore.ABIv2Encoder.encode(types: [.dynamicBytes], values: [value as AnyObject]), expected, "length \(length)")
            let decoded = try XCTUnwrap(TLCore.ABIv2Decoder.decode(types: [.dynamicBytes], data: expected))
            XCTAssertEqual(decoded[0] as? Data, value, "length \(length)")
        }
    }

    func testMalformedHexBytesAreRejectedWithoutChangingStringTextSemantics() throws {
        let malformed = "0x1g"
        XCTAssertNil(TLCore.ABIv2Encoder.convertToData(malformed as AnyObject))
        XCTAssertNil(TLCore.ABIv2Encoder.encodeSingleType(type: .bytes(length: 2), value: malformed as AnyObject))
        XCTAssertNil(TLCore.ABIv2Encoder.encodeSingleType(type: .dynamicBytes, value: malformed as AnyObject))
        let expectedText = words([32, 4]) + rightPaddedWord(Data([0x30, 0x78, 0x31, 0x67]))
        XCTAssertEqual(TLCore.ABIv2Encoder.encode(types: [.string], values: [malformed as AnyObject]), expectedText)
        let decoded = try XCTUnwrap(TLCore.ABIv2Decoder.decode(types: [.string], data: expectedText))
        XCTAssertEqual(decoded[0] as? String, malformed)
    }

    func testInvalidTypedWeb3AddressesAreNotNormalizedAsRawDataAddresses() throws {
        let address = Data(repeating: 0x11, count: 20)
        let expected = Data(repeating: 0, count: 12) + address
        let invalidTRONObject = TLCore.Web3Address(Data([0x41]) + address)
        let invalidWordObject = TLCore.Web3Address(expected)
        XCTAssertFalse(invalidTRONObject.isValid)
        XCTAssertFalse(invalidWordObject.isValid)
        XCTAssertNil(TLCore.ABIv2Encoder.encodeSingleType(type: .address, value: invalidTRONObject as AnyObject))
        XCTAssertNil(TLCore.ABIv2Encoder.encodeSingleType(type: .address, value: invalidWordObject as AnyObject))
        XCTAssertEqual(TLCore.ABIv2Encoder.encodeSingleType(type: .address, value: TLCore.Web3Address(address) as AnyObject), expected)
        XCTAssertEqual(TLCore.ABIv2Encoder.encodeSingleType(type: .address, value: (Data([0x41]) + address) as AnyObject), expected)
        XCTAssertEqual(TLCore.ABIv2Encoder.encodeSingleType(type: .address, value: expected as AnyObject), expected)
        let decoded = try XCTUnwrap(TLCore.ABIv2Decoder.decode(types: [.address], data: expected))
        XCTAssertEqual((decoded[0] as? TLCore.Web3Address)?.addressData, address)
        let wrongHighBytes = Data(repeating: 0, count: 11) + Data([0x41]) + address
        XCTAssertNil(TLCore.ABIv2Decoder.decode(types: [.address], data: wrongHighBytes))
    }

    func testOneDimensionalBatchResultsRetainMainAppBigUIntAndBoolCasts() throws {
        let types: [Parameter] = [.array(type: .uint(bits: 256), length: 0), .array(type: .bool, length: 0)]
        let expected = words([64, 160, 2, 5, 6, 2, 1, 0])
        let decoded = try XCTUnwrap(TLCore.ABIv2Decoder.decode(types: types, data: expected))
        XCTAssertEqual(decoded[0] as? [BigUInt], [BigUInt(5), BigUInt(6)])
        XCTAssertEqual(decoded[1] as? [Bool], [true, false])
        let values: [AnyObject] = [[BigUInt(5), BigUInt(6)] as AnyObject, [true, false] as AnyObject]
        XCTAssertEqual(TLCore.ABIv2Encoder.encode(types: types, values: values), expected)
    }
}

extension ABIv2RegressionTests {
    func testFixedPointTypesCoverEveryWidthAndDecimalPrecisionExactly() throws {
        for byteWidth in 1...32 {
            for decimals in 1...80 {
                let bits = UInt64(byteWidth * 8)
                let precision = UInt64(decimals)
                let signed: Parameter = .fixed(bits: bits, decimals: precision)
                let unsigned: Parameter = .ufixed(bits: bits, decimals: precision)
                XCTAssertEqual(try TLCore.ABIv2TypeParser.parseTypeString("fixed\(bits)x\(decimals)"), signed)
                XCTAssertEqual(try TLCore.ABIv2TypeParser.parseTypeString("ufixed\(bits)x\(decimals)"), unsigned)
                let positiveText = "0." + String(repeating: "0", count: decimals - 1) + "1"
                let negativeText = "-" + positiveText
                XCTAssertEqual(TLCore.ABIv2Encoder.encodeSingleType(type: unsigned, value: positiveText as AnyObject), word(1))
                XCTAssertEqual(TLCore.ABIv2Encoder.encodeSingleType(type: signed, value: negativeText as AnyObject), Data(repeating: 0xff, count: 32))
                let decoded = try XCTUnwrap(TLCore.ABIv2Decoder.decode(types: [signed, unsigned], data: Data(repeating: 0xff, count: 32) + word(1)))
                XCTAssertEqual((decoded[0] as? TLCore.ABIv2.FixedPoint)?.description, negativeText)
                XCTAssertEqual((decoded[1] as? TLCore.ABIv2.FixedPoint)?.description, positiveText)
                XCTAssertEqual((decoded[0] as? TLCore.ABIv2.FixedPoint)?.scaledValue, BigInt(-1))
            }
        }
        XCTAssertEqual(try TLCore.ABIv2TypeParser.parseTypeString("fixed").abiRepresentation, "fixed128x18")
        XCTAssertEqual(try TLCore.ABIv2TypeParser.parseTypeString("ufixed").abiRepresentation, "ufixed128x18")
        for invalid in ["fixed8", "fixed8x0", "fixed8x81", "fixed7x2", "ufixed264x2", "fixed08x2", "fixed8x02", "fixedx2"] {
            XCTAssertThrowsError(try TLCore.ABIv2TypeParser.parseTypeString(invalid), invalid)
        }
    }

    func testFixedPointBoundariesDoNotRoundOrLosePrecision() throws {
        let signed: Parameter = .fixed(bits: 8, decimals: 2)
        let unsigned: Parameter = .ufixed(bits: 8, decimals: 2)
        XCTAssertEqual(TLCore.ABIv2Encoder.encodeSingleType(type: signed, value: "1.27" as AnyObject), signedByteWord(127))
        XCTAssertEqual(TLCore.ABIv2Encoder.encodeSingleType(type: signed, value: "-1.28" as AnyObject), signedByteWord(-128))
        XCTAssertEqual(TLCore.ABIv2Encoder.encodeSingleType(type: unsigned, value: "2.55" as AnyObject), word(255))
        XCTAssertEqual(TLCore.ABIv2Encoder.encodeSingleType(type: signed, value: "1.2700" as AnyObject), word(127))
        XCTAssertEqual(TLCore.ABIv2Encoder.encodeSingleType(type: signed, value: "-0.00" as AnyObject), word(0))
        XCTAssertEqual(TLCore.ABIv2Encoder.encodeSingleType(type: unsigned, value: "-0" as AnyObject), word(0))
        for invalid in ["1.28", "-1.29", "0.001", "1e-2", "0x01", "NaN", "", "+", "1.", ".1", " 1"] {
            XCTAssertNil(TLCore.ABIv2Encoder.encodeSingleType(type: signed, value: invalid as AnyObject), invalid)
        }
        XCTAssertNil(TLCore.ABIv2Encoder.encodeSingleType(type: unsigned, value: "-0.01" as AnyObject))
        XCTAssertNil(TLCore.ABIv2Encoder.encodeSingleType(type: unsigned, value: "2.56" as AnyObject))
        XCTAssertNil(TLCore.ABIv2Encoder.encodeSingleType(type: signed, value: Double(0.1) as AnyObject))
        let wrongScale = try XCTUnwrap(TLCore.ABIv2.FixedPoint(scaledValue: BigInt(1), decimals: 3))
        XCTAssertNil(TLCore.ABIv2Encoder.encodeSingleType(type: signed, value: wrongScale as AnyObject))
        XCTAssertNil(TLCore.ABIv2Decoder.decode(types: [signed], data: word(128)))
        XCTAssertNil(TLCore.ABIv2Decoder.decode(types: [unsigned], data: word(256)))
        let maximum = (BigUInt(1) << 256) - 1
        let exact = try XCTUnwrap(TLCore.ABIv2.FixedPoint(scaledValue: BigInt(maximum), decimals: 80))
        XCTAssertEqual(TLCore.ABIv2Encoder.encodeSingleType(type: .ufixed(bits: 256, decimals: 80), value: exact as AnyObject), Data(repeating: 0xff, count: 32))
        XCTAssertEqual(TLCore.ABIv2Encoder.encodeSingleType(type: .ufixed(bits: 256, decimals: 80), value: exact.description as AnyObject), Data(repeating: 0xff, count: 32))
    }

    func testZeroLengthFixedArraysRemainDistinctFromDynamicArrays() throws {
        let staticZero = try TLCore.ABIv2TypeParser.parseTypeString("uint256[0]")
        let dynamicZero = try TLCore.ABIv2TypeParser.parseTypeString("string[0]")
        let empty = [AnyObject]() as AnyObject
        XCTAssertEqual(staticZero, Parameter.fixedArray(type: .uint(bits: 256), length: 0))
        XCTAssertNotEqual(staticZero, Parameter.array(type: .uint(bits: 256), length: 0))
        XCTAssertEqual(Parameter.fixedArray(type: .bool, length: 2), Parameter.array(type: .bool, length: 2))
        XCTAssertEqual(staticZero.abiRepresentation, "uint256[0]")
        for (zero, expected) in [(staticZero, word(7)), (dynamicZero, words([64, 7]))] {
            let types: [Parameter] = [zero, .uint(bits: 256)]
            XCTAssertEqual(TLCore.ABIv2Encoder.encode(types: types, values: [empty, BigUInt(7) as AnyObject]), expected)
            let decoded = try XCTUnwrap(TLCore.ABIv2Decoder.decode(types: types, data: expected))
            XCTAssertTrue(try XCTUnwrap(decoded[0] as? [AnyObject]).isEmpty)
            XCTAssertEqual(decoded[1] as? BigUInt, BigUInt(7))
        }
        let array = try TLCore.ABIv2TypeParser.parseTypeString("string[0][]")
        let values = [empty, empty] as AnyObject
        // Both zero-sized dynamic tails begin at the end of their container.
        let expected = words([32, 2, 64, 64])
        XCTAssertEqual(TLCore.ABIv2Encoder.encode(types: [array], values: [values]), expected)
        let decoded = try XCTUnwrap(TLCore.ABIv2Decoder.decode(types: [array], data: expected))
        let rows = try XCTUnwrap(decoded[0] as? [[AnyObject]])
        XCTAssertEqual(rows.count, 2)
        XCTAssertTrue(rows.allSatisfy { $0.isEmpty })
        let json = """
        {"type":"function","name":"f","inputs":[{"name":"zero","type":"tuple[0]","components":[{"name":"s","type":"string"}]}],"outputs":[],"stateMutability":"pure"}
        """
        let element = try parseRecord(json)
        guard case let .function(function) = element else { return XCTFail("Expected function") }
        XCTAssertEqual(function.signature, "f((string)[0])")
        XCTAssertEqual(element.encodeParameters([empty]), function.methodEncoding + word(32))
        XCTAssertNotNil(element.decodeInputData(function.methodEncoding + word(32)))
    }

    func testGeneralABIDecodingCanExplicitlyDisableLegacyTokenMetadata() throws {
        let legacy = rightPaddedWord(Data("USDT".utf8))
        XCTAssertEqual(TLCore.ABIv2Decoder.decode(types: [.string], data: legacy)?.first as? String, "USDT")
        for invalid in [legacy, word(0), word(32)] {
            XCTAssertNil(TLCore.ABIv2Decoder.decode(types: [.string], data: invalid, allowLegacyBytes32: false))
            XCTAssertNil(TLCore.ABIv2Decoder.decodeSignleType(type: .string, data: invalid, allowLegacyBytes32: false).value)
        }
        let standard = words([32, 4]) + legacy
        XCTAssertEqual(TLCore.ABIv2Decoder.decode(types: [.string], data: standard, allowLegacyBytes32: false)?.first as? String, "USDT")
    }

    func testLegacyBytes32FallbackRejectsLeftPaddedOffsetWords() {
        XCTAssertNil(TLCore.ABIv2Decoder.decode(types: [.string], data: word(32)))
        XCTAssertNil(TLCore.ABIv2Decoder.decode(types: [.string], data: word(64)))
        XCTAssertEqual(TLCore.ABIv2Decoder.decode(types: [.string], data: word(0))?.first as? String, "")
        XCTAssertEqual(TLCore.ABIv2Decoder.decode(types: [.string], data: rightPaddedWord(Data("USDT".utf8)))?.first as? String, "USDT")
    }

    func testDynamicStringAndBytesRejectDirtyPadding() {
        let dirtyString = words([32, 1]) + Data("a".utf8) + Data(repeating: 0xff, count: 31)
        XCTAssertNil(TLCore.ABIv2Decoder.decode(types: [.string], data: dirtyString))
        let dirtyBytes = words([32, 1]) + Data([0xaa]) + Data(repeating: 0xff, count: 31)
        XCTAssertNil(TLCore.ABIv2Decoder.decode(types: [.dynamicBytes], data: dirtyBytes))
        let clean = words([32, 1]) + rightPaddedWord(Data("a".utf8))
        XCTAssertEqual(TLCore.ABIv2Decoder.decode(types: [.string], data: clean)?.first as? String, "a")
    }

    func testDecodeSingleTypeUsesEnclosingHeadAsOffsetFloor() {
        let strings: Parameter = .array(type: .string, length: 0)
        let data = words([32, 0])
        XCTAssertNil(TLCore.ABIv2Decoder.decode(types: [strings, .uint(bits: 256)], data: data))
        let rejected = TLCore.ABIv2Decoder.decodeSignleType(type: strings, data: data, pointer: 0, allowLegacyBytes32: false, minimumTail: 64)
        XCTAssertNil(rejected.value)
        XCTAssertNil(rejected.bytesConsumed)
    }

    func testDecodeSingleTypeRejectsIncompleteOrInvalidEnclosingHeads() {
        let cases: [(Parameter, Data)] = [
            (.string, rightPaddedWord(Data("USDT".utf8))),
            (.string, word(0)),
            (.uint(bits: 256), word(7))
        ]
        for (type, data) in cases {
            for headWidth in [UInt64(0), 31, 64, UInt64.max] {
                for allowLegacy in [false, true] {
                    let result = TLCore.ABIv2Decoder.decodeSignleType(
                        type: type, data: data, allowLegacyBytes32: allowLegacy,
                        minimumTail: headWidth
                    )
                    XCTAssertNil(result.value)
                    XCTAssertNil(result.bytesConsumed)
                }
            }
        }
        let truncated = TLCore.ABIv2Decoder.decodeSignleType(
            type: .uint(bits: 256), data: words([7, 9]), pointer: 32,
            allowLegacyBytes32: false, minimumTail: 96
        )
        XCTAssertNil(truncated.value)
        XCTAssertNil(truncated.bytesConsumed)
    }

    func testDecodeSingleTypePreservesValidLegacyAndZeroWidthHeads() throws {
        let headWidths: [UInt64?] = [nil, 32]
        for text in ["USDT", ""] {
            let data = rightPaddedWord(Data(text.utf8))
            for headWidth in headWidths {
                let result = TLCore.ABIv2Decoder.decodeSignleType(
                    type: .string, data: data, allowLegacyBytes32: true,
                    minimumTail: headWidth
                )
                XCTAssertEqual(result.value as? String, text)
                XCTAssertEqual(result.bytesConsumed, UInt64(32))
            }
        }
        let empty = TLCore.ABIv2Decoder.decodeSignleType(
            type: .tuple(types: []), data: Data(), allowLegacyBytes32: false,
            minimumTail: 0
        )
        XCTAssertTrue(try XCTUnwrap(empty.value as? [AnyObject]).isEmpty)
        XCTAssertEqual(empty.bytesConsumed, UInt64(0))
    }

    func testDecodeSingleTypeKeepsThreeFourAndFiveArgumentFunctionReferences() {
        typealias Result = (value: AnyObject?, bytesConsumed: UInt64?)
        let original: (Parameter, Data, UInt64) -> Result = TLCore.ABIv2Decoder.decodeSignleType
        let withLegacy: (Parameter, Data, UInt64, Bool) -> Result = TLCore.ABIv2Decoder.decodeSignleType
        let withHead: (Parameter, Data, UInt64, Bool, UInt64?) -> Result = TLCore.ABIv2Decoder.decodeSignleType
        let data = words([7, 9])
        let results = [
            original(.uint(bits: 256), data, 32),
            withLegacy(.uint(bits: 256), data, 32, false),
            withHead(.uint(bits: 256), data, 32, false, 64)
        ]
        for result in results {
            XCTAssertEqual(result.value as? BigUInt, BigUInt(9))
            XCTAssertEqual(result.bytesConsumed, UInt64(32))
        }
        let metadata = rightPaddedWord(Data("USDT".utf8))
        XCTAssertEqual(original(.string, metadata, 0).value as? String, "USDT")
        XCTAssertEqual(withLegacy(.string, metadata, 0, true).value as? String, "USDT")
        XCTAssertNil(withLegacy(.string, metadata, 0, false).value)
    }

    func testABIConversionRejectsMalformedAddressAndNormalizesOddHex() {
        let malformedAddress = "0x" + String(repeating: "1g", count: 20)
        XCTAssertNil(TLCore.ABIv2Encoder.encodeSingleType(type: .address, value: malformedAddress as AnyObject))
        XCTAssertNil(TLCore.ABIv2Encoder.encodeSingleType(type: .address, value: TLCore.Web3Address(malformedAddress) as AnyObject))
        XCTAssertEqual(TLCore.ABIv2Encoder.convertToData("0x1" as AnyObject), Data([1]))
        XCTAssertEqual(TLCore.ABIv2Encoder.convertToData("0x123" as AnyObject), Data([0x01, 0x23]))
        XCTAssertEqual(TLCore.ABIv2Encoder.convertToData("0XABCD" as AnyObject), Data([0xab, 0xcd]))
        XCTAssertNil(TLCore.ABIv2Encoder.encodeSingleType(type: .uint(bits: 256), value: String(repeating: "9", count: 10000) as AnyObject))
        XCTAssertEqual(TLCore.ABIv2Encoder.encodeSingleType(type: .uint(bits: 256), value: (String(repeating: "0", count: 10000) + "1") as AnyObject), word(1))
    }
}

extension ABIv2RegressionTests {
    func testStaticBytesAndFunctionRejectDirtyRightPadding() throws {
        for length in 1...31 {
            let type: Parameter = .bytes(length: UInt64(length))
            let value = Data(repeating: 0x12, count: length)
            let dirty = value + Data([1]) + Data(repeating: 0, count: 31 - length)
            XCTAssertNil(TLCore.ABIv2Decoder.decode(types: [type], data: dirty))
        }
        let function = Data(repeating: 0x11, count: 24)
        let dirtyFunction = function + Data([1]) + Data(repeating: 0, count: 7)
        XCTAssertNil(TLCore.ABIv2Decoder.decode(types: [.function], data: dirtyFunction))
        let validFunction = function + Data(repeating: 0, count: 8)
        XCTAssertEqual(TLCore.ABIv2Decoder.decode(types: [.function], data: validFunction)?.first as? Data, function)
    }

    func testContractDeploymentSentinelCannotBecomeAnABIAddress() {
        var address = TLCore.Web3Address(Data(repeating: 0x11, count: 20))
        address.type = .contractDeployment
        XCTAssertNil(TLCore.ABIv2Encoder.encodeSingleType(type: .address, value: address as AnyObject))
    }

    func testTypeTraversalBudgetIsSharedAcrossRootParameters() {
        var shared: Parameter = .tuple(types: [])
        for _ in 0..<18 { shared = .tuple(types: [shared, shared]) }
        let types = Array(repeating: shared, count: 1000)
        let values = Array(repeating: [AnyObject]() as AnyObject, count: 1000)
        // Indirect enum and Array COW let this tiny schema describe hundreds of
        // millions of visits. Repeated root types must share the work budget.
        XCTAssertNil(TLCore.ABIv2Encoder.encode(types: types, values: values))
        XCTAssertNil(TLCore.ABIv2Decoder.decode(types: types, data: Data()))
    }

    func testJSONContractReturnCanDisableLegacyMetadataWithoutInternalMembers() throws {
        let json = """
        {"type":"function","name":"name","inputs":[],"outputs":[{"name":"value","type":"string"}],"stateMutability":"view"}
        """
        let element = try parseRecord(json)
        let metadata = rightPaddedWord(Data("USDT".utf8))
        XCTAssertEqual(element.decodeReturnData(metadata)?["value"] as? String, "USDT")
        XCTAssertNil(element.decodeReturnData(metadata, allowLegacyBytes32: false))
        XCTAssertEqual(element.decodeReturnData(words([32, 4]) + metadata, allowLegacyBytes32: false)?["value"] as? String, "USDT")
    }
}


final class HexDecodingRegressionTests: XCTestCase {
    func testHexDecoderRejectsIncompleteAndInvalidBytePairs() {
        let malformed = ["0", "0x1", "abc", "0xabc", "1g", "g1", "01g2", "012g",
                         " a", "a ", "+1", "-1", "0x12\n", "aé", "Ａ１"]
        for value in malformed {
            XCTAssertNil(Data(hexString: value), value)
            XCTAssertNil(Data.fromHex(value), value)
        }
    }

    func testHexDecoderPreservesCompleteBytesAndEmptyPayloads() {
        for prefix in ["", "0x"] {
            XCTAssertEqual(Data(hexString: prefix), Data())
            XCTAssertEqual(Data.fromHex(prefix), Data())
            XCTAssertEqual(Data(hexString: prefix + "00aB10fF"), Data([0x00, 0xab, 0x10, 0xff]))
            XCTAssertEqual(Data.fromHex(prefix + "00aB10fF"), Data([0x00, 0xab, 0x10, 0xff]))
        }
    }

    func testAddressesRejectTruncatedAndMalformedHex() {
        let leadingBytes = String(repeating: "11", count: 19)
        let valid = leadingBytes + "ab"
        let expected = Data(repeating: 0x11, count: 19) + Data([0xab])
        let malformed = [String(valid.dropLast()), leadingBytes + "ag", leadingBytes + "ga",
                         String(valid.dropLast(2)), valid + "00"]
        for prefix in ["", "0x"] {
            XCTAssertEqual(TLCore.Address(string: prefix + valid)?.data, expected)
            XCTAssertTrue(TLCore.Web3Address(prefix + valid).isValid)
            for value in malformed {
                XCTAssertNil(TLCore.Address(string: prefix + value), prefix + value)
                XCTAssertFalse(TLCore.Web3Address(prefix + value).isValid, prefix + value)
            }
        }
    }

    func testJSONHexFieldsRejectMalformedByteStrings() throws {
        struct Payload: Decodable {
            let value: Data
            enum CodingKeys: String, CodingKey { case value }
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                value = try container.decodeHexString(forKey: .value)
            }
        }
        for value in ["abc", "1g", "g1"] {
            let json = try JSONSerialization.data(withJSONObject: ["value": value])
            XCTAssertThrowsError(try JSONDecoder().decode(Payload.self, from: json))
        }
        let json = try JSONSerialization.data(withJSONObject: ["value": "00ab"])
        XCTAssertEqual(try JSONDecoder().decode(Payload.self, from: json).value, Data([0x00, 0xab]))
    }
}

final class StringAddressValidationTests: XCTestCase {
    func testAcceptsCompleteEVMHexAddresses() {
        let addresses = [
            "45245bc59219eeaaf6cd3f382e078a461ff9de7b",
            "45245BC59219EEAAF6CD3F382E078A461FF9DE7B",
            "45245bC59219eEaAf6Cd3F382e078A461ff9dE7b",
            String(repeating: "00", count: 20),
            String(repeating: "ff", count: 20)
        ]
        for prefix in ["", "0x", "0X"] {
            for address in addresses {
                XCTAssertTrue((prefix + address).isAddress, prefix + address)
            }
        }
    }

    func testRejectsTextPreviouslyAcceptedByUTF8HexLength() {
        // Each input occupies 10 UTF-8 bytes, which the old predicate accepted.
        for value in ["helloworld", "1234567890", "0x12345678", "😀😀ab", String(repeating: "é", count: 5)] {
            XCTAssertFalse(value.isAddress, value)
        }
    }

    func testRejectsMalformedHexWithoutRepairingInput() {
        let valid = String(repeating: "ab", count: 20)
        let malformed = [
            "", String(valid.dropLast()), valid + "a", String(valid.dropLast(2)), valid + "ab",
            String(repeating: "00", count: 32),
            "g" + String(valid.dropFirst()), String(valid.dropLast()) + "g",
            " " + valid, valid + "\n",
            "+1" + String(valid.dropFirst(2)), "-1" + String(valid.dropFirst(2)),
            String(repeating: "Ａ", count: 40)
        ]
        for prefix in ["", "0x", "0X"] {
            for value in malformed {
                XCTAssertFalse((prefix + value).isAddress, prefix + value)
            }
        }
        for prefix in ["0x", "0X"] {
            XCTAssertFalse((prefix + "0x" + valid).isAddress)
            XCTAssertFalse((prefix + "0X" + valid).isAddress)
        }
    }

    func testKeepsTRONValidationSeparateFromEVMHexValidation() {
        let tronAddress = "T9yD14Nj9j7xAB4dbGeiX9h8unkKHxuWwb"
        XCTAssertTrue(tronAddress.isTRXAddress())
        XCTAssertFalse(tronAddress.isAddress)

        let tronHex = "41" + String(repeating: "00", count: 20)
        for prefix in ["", "0x", "0X"] {
            XCTAssertTrue((prefix + tronHex).isEIP712TronAddress())
            XCTAssertFalse((prefix + tronHex).isAddress)
        }
    }
}
