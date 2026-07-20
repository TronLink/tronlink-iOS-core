import XCTest
@testable import TLCore
import TronKeystore

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

    func testBase58CheckRoundTripWithFlickrAlphabet() {
        let payload = Data([0x00, 0x41, 0x88, 0xff, 0x10, 0x7c, 0x23, 0x5a])
        let encoded = String(base58CheckEncoding: payload, alphabet: Base58String.flickrAlphabet)
        let decoded = Data(base58CheckDecoding: encoded, alphabet: Base58String.flickrAlphabet)

        XCTAssertNotEqual(encoded, String(base58CheckEncoding: payload))
        XCTAssertEqual(decoded, payload)
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
