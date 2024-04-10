import XCTest
import TLCore
import TronKeystore

class Tests: XCTestCase {
    
    private let password: String = "Aa123456"
    private let walletAddress: String = "TJBE61UKoXkZy2LEJQcjH3Awm8sqdBJioC"
    
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
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure() {
            // Put the code you want to measure the time of here.
        }
    }
    
    // create new wallet
    func testCreateWallet() {
        TLWalletCore.createWalletAccount(keyStore: self.keyStore, password: self.password) {  result in
            switch result {
            case .success(let account):
                let walletAddress = String(base58CheckEncoding: account.address.data)
                print("createWallet: \(walletAddress)")
                break
            case .failure(let error):
                print(error)
                break
            }
        }
    }
    
    // Sign Transaction
    func testSignTransaction() {
        let data = TronTransaction().rawData.data() ?? Data() // Your TronTransaction data
        let signResult = TLWalletCore.signTranscation(keyStore: self.keyStore, transaction: data, password: self.password, address: self.walletAddress)
        
        if case .success(let data) = signResult {
            print(data)
        }else if case .failure(let error) = signResult {
            print(error)
        }else {
            print("failedToSignTransaction")
        }
    }
    
    // Sign String
    func testSignMessage() {
        TLWalletCore.createWalletAccount(keyStore: self.keyStore, password: self.password) {  result in
            switch result {
            case .success(let account):
                let walletAddress = String(base58CheckEncoding: account.address.data)
                print("createWallet: \(walletAddress)")
                
                let unSignedString = "abcd"
                // sign v1
                let result1 = TLWalletCore.signString(keyStore: self.keyStore, unSignedString: unSignedString, password: self.password, address: walletAddress)
                print("sign v1: \(result1)")
                
                // sign v2
                let messageSignV2: TLMessageSignV2Type = .SIGN_MESSAGE_V2_STRING
                let result2 = TLWalletCore.signStringV2(keyStore: self.keyStore, unSignedString: unSignedString, password: self.password, address: walletAddress, messageSignV2)
                print("sign v2: \(result2)")

                break
            case .failure(let error):
                print(error)
                break
            }
        }
    }

}
