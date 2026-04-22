
import TronKeystore
import TronCore
import web3swift
import CryptoSwift

public enum TLMessageSignV2Type {
    //v2
    case SIGN_MESSAGE_V2_STRING
    case SIGN_MESSAGE_V2_HASHSTRING
    case SIGN_MESSAGE_V2_ARRAY
}

public enum TLMessageSignType {
    case SIGN_MESSAGE
    case SIGN_MESSAGE_V2
}

public class TLWalletCore: NSObject {
    
    public static func signTranscation(keyStore: KeyStore, transaction: Data, password: String, address: String, _ dappChainId: String = "") -> Result<Data, KeystoreError> {
        
        for account in keyStore.accounts {
            if address == account.address.data.addressString {
                var newHash: Data = transaction.sha256T()
                if !dappChainId.isEmpty {
                    if let mainGateData = Data(hexString: dappChainId) {
                        newHash.append(mainGateData)
                        newHash = newHash.sha256T()
                    }
                }
                do {
                    var data = try keyStore.signHash(newHash, account: account, password: password)
                    if data[64] >= 27 {
                        data[64] -= 27
                    }
                    return .success(data)
                } catch _ {
                    return .failure(KeystoreError.failedToSignTransaction)
                }
            }
        }
        return .failure(KeystoreError.failedToSignTransaction)
    }

    
    /// sign tron transaction
    /// - Parameters:
    ///   - keyStore: KeyStore
    ///   - transaction: Transaction
    ///   - password: wallet password
    ///   - address: wallet address
    ///   - dappChainId: Optional, defalut is mainChain, dappChainId needs to pass in ChianId
    /// - Returns: signed TronTransaction
    public static func signTranscation(keyStore: KeyStore, transaction: TronTransaction, password: String, address: String, _ dappChainId: String = "") -> Result<TronTransaction, KeystoreError> {
        
        for account in keyStore.accounts {
            if address == account.address.data.addressString {
                if let hash: Data = transaction.rawData.data()?.sha256T(), let list = transaction.rawData.contractArray, list.count > 0 {
                    for _ in list {
                        var newHash: Data = hash
                        if !dappChainId.isEmpty {
                            if let mainGateData = Data(hexString: dappChainId) {
                                newHash.append(mainGateData)
                                newHash = newHash.sha256T()
                            }
                        }
                        do {
                            var data = try keyStore.signHash(newHash, account: account, password: password)
                            if data[64] >= 27 {
                                data[64] -= 27
                            }
                            transaction.signatureArray.add(data as Any)
                            return .success(transaction)
                        } catch _ {
                            return .failure(KeystoreError.failedToSignTransaction)
                        }
                    }
                } else {
                    return .failure(KeystoreError.failedToParseJSON)
                }
            }
        }
        return .failure(KeystoreError.failedToSignTransaction)
    }

}

//MARK: - Create
extension TLWalletCore {
    public static func createWalletAccount(keyStore: KeyStore, password: String, completion: @escaping (Result<TronKeystore.Account, KeystoreError>) -> Void) {
        do {
            let account = try keyStore.createAccount(password: password, type: .hierarchicalDeterministicWallet)
            completion(.success(account))
        } catch {
            completion(.failure(.failedToCreateWallet))
        }
    }
}

//MARK: - Export
extension TLWalletCore {
    public static func walletExportPrivateKey(keyStore: KeyStore, password: String, address: String) -> String{
        
        for account in keyStore.accounts {
            if address == account.address.data.addressString {
                do {
                    var privateKey = try keyStore.exportPrivateKey(account: account, password: password)
                    defer {
                        privateKey = Data()
                    }
                    return privateKey.hexString
                } catch _ {}
            }
        }
        return ""
    }
    
    
    public static func walletExportMnemonic(keyStore: KeyStore, password: String, address: String) -> String {
        
        for account in keyStore.accounts {
            if address == account.address.data.addressString {
                do {
                    var mnemonic = try keyStore.exportMnemonic(account: account, password: password)
                    defer {
                        mnemonic = ""
                    }
                    return mnemonic
                } catch _ {}
            }
        }
        return ""
    }
}

//MARK: - Sign
extension TLWalletCore {
    /**
     * @brief Sign a string using a KeyStore
     *
     * @param keyStore KeyStore instance containing account information
     * @param unSignedString The string to be signed
     * @param password Password to unlock the KeyStore
     * @param address Account address associated with the string to be signed
     * @return The signed string
     */
    public static func signString(keyStore: KeyStore, unSignedString: String, password: String, address: String) -> String {
        return TLWalletCore.signTypeString(keyStore: keyStore, unSignedString: unSignedString, password: password, address: address, signType:.SIGN_MESSAGE)
    }
    
    /**
     * @brief Sign a string using a KeyStore (V2 version)
     *
     * @param keyStore KeyStore instance containing account information
     * @param unSignedString The string to be signed
     * @param password Password to unlock the KeyStore
     * @param address Account address associated with the string to be signed
     * @param messageType Message type, defaults to SIGN_MESSAGE_V2_STRING
     * @return The signed string
     */
    public static func signStringV2(keyStore: KeyStore, unSignedString: String, password: String, address: String,_ messageType:TLMessageSignV2Type = .SIGN_MESSAGE_V2_STRING) -> String {
        return TLWalletCore.signTypeString(keyStore: keyStore, unSignedString: unSignedString, password: password, address: address, signType:.SIGN_MESSAGE_V2, messageType)
    }
    
    /**
     * @brief Sign a string using a KeyStore, supporting specified sign type and message type
     *
     * @param keyStore KeyStore instance containing account information
     * @param unSignedString The string to be signed
     * @param password Password to unlock the KeyStore
     * @param address Account address associated with the string to be signed
     * @param signType Sign type, defaults to SIGN_MESSAGE
     * @param messageType Message type, defaults to SIGN_MESSAGE_V2_STRING
     * @return The signed string
     */
    public static func signTypeString(keyStore: KeyStore, unSignedString: String, password: String, address: String, signType: TLMessageSignType = .SIGN_MESSAGE, _ messageType:TLMessageSignV2Type = .SIGN_MESSAGE_V2_STRING) -> String {
        // Find the account matching the address
        guard let account = keyStore.accounts.first(where: { $0.address.data.addressString == address }) else {
            return ""
        }

        var sha3Data =  TLWalletCore.convertSignStringToSha3Data(unSignedString: unSignedString)
        if signType == .SIGN_MESSAGE_V2 {
            sha3Data = TLWalletCore.convertSignStringV2ToSha3Data(unSignedString: unSignedString)
        }
        do {
            var signature = try keyStore.signHash(sha3Data, account: account, password: password)
            if signature[64] >= 27 {
                signature[64] -= 27
            }
            return signature.toHexString().add0x
        }catch _ {
            return ""
        }
    }
    
    /**
     * @brief Convert the string to be signed into SHA3 data
     *
     * @param unSignedString The string to be signed
     * @return The converted SHA3 data
     */
    public static func convertSignStringToSha3Data(unSignedString: String) -> Data {
        let signString = unSignedString.signStringHexEncoded
        let persondata = Data.init(hex: signString)

        var apendData = Data()
        let prefix = "\u{19}TRON Signed Message:\n32"
        guard let prefixData = prefix.data(using: .ascii) else { return Data() }
        apendData.append(prefixData)
        apendData.append(persondata)

        //sh3
        let sha3 = SHA3(variant: .keccak256)
        let Sh3Data =  Data(bytes: sha3.calculate(for: apendData.bytesT))
        return Sh3Data
    }
    
    /**
     * @brief Convert the string to be signed into SHA3 data (V2 version)
     *
     * @param unSignedString The string to be signed
     * @param messageType Message type, defaults to SIGN_MESSAGE_V2_STRING
     * @return The converted SHA3 data
     */
    public static func convertSignStringV2ToSha3Data(unSignedString: String, messageType:TLMessageSignV2Type = .SIGN_MESSAGE_V2_STRING) -> Data {
        
        var persondata = Data.init(hex: unSignedString)
        if case .SIGN_MESSAGE_V2_ARRAY = messageType { //bytes
            let list = unSignedString.split(separator: ",")
            var byteList:[UInt8] = [UInt8]()
            list.forEach { item in
                if let value = (UInt8)(String(item)) {
                    byteList.append(value)
                }
            }
            persondata = Data.init(bytes:byteList)
        }else if case .SIGN_MESSAGE_V2_STRING = messageType { //String
            persondata = unSignedString.data(using: .utf8) ?? Data()
        }else if case .SIGN_MESSAGE_V2_HASHSTRING = messageType { //HexStringType
            persondata = Data.init(hex: unSignedString)
        }

        let prefix = "\u{19}TRON Signed Message:\n\(persondata.count)"
        guard let prefixData = prefix.data(using: .ascii) else { return Data() }

        var apendData = Data()
        apendData.append(prefixData)
        apendData.append(persondata)

        //sh3
        let sha3 = SHA3(variant: .keccak256)
        let Sh3Data =  Data(bytes: sha3.calculate(for: apendData.bytesT))
        return Sh3Data
    }
    
}
