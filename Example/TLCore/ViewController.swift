//

import UIKit
import TLCore
import TronKeystore

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    /**
     Demo
     **/
    // create new wallet
    func createWallet() {
        let keysDirectory = URL(fileURLWithPath: "path")
        let keyStore = try! KeyStore(keyDirectory: keysDirectory)
        TLWalletCore.createWalletAccount(keyStore: keyStore, password: "password") {  result in
            switch result {
            case .success(let account):
                let walletAddress = String(base58CheckEncoding: account.address.data)
                break
            case .failure(let error):
                print(error)
                break
            }
        }
    }
    
    // Sign Transaction
    func signTransaction() {
        let keysDirectory = URL(fileURLWithPath: "path")
        let keyStore = try! KeyStore(keyDirectory: keysDirectory)

        let data = TronTransaction().rawData.data() ?? Data()
        let signResult = TLWalletCore.signTranscation(keyStore: keyStore, transaction: data, password: "password", address: "walletAddress", "chainId")
        
        if case .success(let data) = signResult {
            print(data)
        }else if case .failure(let error) = signResult {
            print(error)
        }else {
            print("failedToSignTransaction")
        }
    }
    
    // Sign String
    func signMessage() {
        let keysDirectory = URL(fileURLWithPath: "path")
        let keyStore = try! KeyStore(keyDirectory: keysDirectory)

        let unSignedString = ""
        // sign v1
        let result1 = TLWalletCore.signString(keyStore: keyStore, unSignedString: unSignedString, password: "password", address: "walletAddress")
        
        // sign v2
        let messageSignV2: TLMessageSignV2Type = .SIGN_MESSAGE_V2_STRING
        let result2 = TLWalletCore.signStringV2(keyStore: keyStore, unSignedString: unSignedString, password: "password", address: "walletAddress", messageSignV2)
    }

}

