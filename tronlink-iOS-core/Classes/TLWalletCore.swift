
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
                    guard data.count >= 65 else {
                        return .failure(KeystoreError.failedToSignTransaction)
                    }
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
                    var collectedSignatures: [Data] = []
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
                            guard data.count >= 65 else {
                                return .failure(KeystoreError.failedToSignTransaction)
                            }
                            if data[64] >= 27 {
                                data[64] -= 27
                            }
                            collectedSignatures.append(data)
                        } catch _ {
                            return .failure(KeystoreError.failedToSignTransaction)
                        }
                    }
                    collectedSignatures.forEach { transaction.signatureArray.add($0 as Any) }
                    return .success(transaction)
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
    public static func walletExportPrivateKey(keyStore: KeyStore, password: String, address: String) -> Result<String, KeystoreError> {
        guard let account = keyStore.accounts.first(where: { $0.address.data.addressString == address }) else {
            return .failure(.accountNotFound)
        }

        do {
            var privateKey = try keyStore.exportPrivateKey(account: account, password: password)
            defer {
                privateKey = Data()
            }
            guard !privateKey.isEmpty else {
                return .failure(.failedToExportPrivateKey)
            }
            return .success(privateKey.hexString)
        } catch {
            return .failure(.failedToExportPrivateKey)
        }
    }
    
    
    public static func walletExportMnemonic(keyStore: KeyStore, password: String, address: String) -> Result<String, KeystoreError> {
        guard let account = keyStore.accounts.first(where: { $0.address.data.addressString == address }) else {
            return .failure(.accountNotFound)
        }

        do {
            let mnemonic = try keyStore.exportMnemonic(account: account, password: password)
            guard !mnemonic.isEmpty else {
                return .failure(.failedToExportMnemonic)
            }
            return .success(mnemonic)
        } catch {
            return .failure(.failedToExportMnemonic)
        }
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
     * @return Result containing the signed string or a signing error
     */
    public static func signString(keyStore: KeyStore, unSignedString: String, password: String, address: String) -> Result<String, KeystoreError> {
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
     * @return Result containing the signed string or a signing error
     */
    public static func signStringV2(keyStore: KeyStore, unSignedString: String, password: String, address: String,_ messageType:TLMessageSignV2Type = .SIGN_MESSAGE_V2_STRING) -> Result<String, KeystoreError> {
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
     * @return Result containing the signed string or a signing error
     */
    public static func signTypeString(keyStore: KeyStore, unSignedString: String, password: String, address: String, signType: TLMessageSignType = .SIGN_MESSAGE, _ messageType:TLMessageSignV2Type = .SIGN_MESSAGE_V2_STRING) -> Result<String, KeystoreError> {
        // Find the account matching the address
        guard let account = keyStore.accounts.first(where: { $0.address.data.addressString == address }) else {
            return .failure(.accountNotFound)
        }

        do {
            var sha3Data = try TLWalletCore.convertSignStringToSha3Data(unSignedString: unSignedString)
            if signType == .SIGN_MESSAGE_V2 {
                sha3Data = try TLWalletCore.convertSignStringV2ToSha3Data(unSignedString: unSignedString, messageType: messageType)
            }
            guard sha3Data.count == 32 else {
                return .failure(.invalidSignInput)
            }
            var signature = try keyStore.signHash(sha3Data, account: account, password: password)
            guard signature.count >= 65 else {
                return .failure(.failedToSignMessage)
            }
            if signature[64] >= 27 {
                signature[64] -= 27
            }
            return .success(signature.toHexString().add0x)
        } catch KeystoreError.invalidSignInput {
            return .failure(.invalidSignInput)
        } catch {
            return .failure(.failedToSignMessage)
        }
    }
    
    /**
     * @brief Convert the string to be signed into SHA3 data
     *
     * @param unSignedString The string to be signed
     * @return The converted SHA3 data
     */
    public static func convertSignStringToSha3Data(unSignedString: String) throws -> Data {
        let signString = unSignedString.signStringHexEncoded
        let persondata = Data.init(hex: signString)
        guard !persondata.isEmpty else { throw KeystoreError.invalidSignInput }

        var apendData = Data()
        let prefix = "\u{19}TRON Signed Message:\n32"
        guard let prefixData = prefix.data(using: .ascii) else { throw KeystoreError.invalidSignInput }
        apendData.append(prefixData)
        apendData.append(persondata)

        //sh3
        let sha3 = SHA3(variant: .keccak256)
        let sha3Data = Data(sha3.calculate(for: apendData.bytesT))
        return sha3Data
    }
    
    /**
     * @brief Convert the string to be signed into SHA3 data (V2 version)
     *
     * @param unSignedString The string to be signed
     * @param messageType Message type, defaults to SIGN_MESSAGE_V2_STRING
     * @return The converted SHA3 data
     */
    public static func convertSignStringV2ToSha3Data(unSignedString: String, messageType:TLMessageSignV2Type = .SIGN_MESSAGE_V2_STRING) throws -> Data {
        let persondata = try parseBytes(unSignedString, type: messageType)

        let prefix = "\u{19}TRON Signed Message:\n\(persondata.count)"
        guard let prefixData = prefix.data(using: .ascii) else { throw KeystoreError.invalidSignInput }

        var apendData = Data()
        apendData.append(prefixData)
        apendData.append(persondata)

        //sh3
        let sha3 = SHA3(variant: .keccak256)
        let sha3Data = Data(sha3.calculate(for: apendData.bytesT))
        return sha3Data
    }

    private static func parseBytes(_ string: String, type: TLMessageSignV2Type) throws -> Data {
        switch type {
        case .SIGN_MESSAGE_V2_ARRAY:
            let parts = string.split(separator: ",")
            var bytes: [UInt8] = []
            bytes.reserveCapacity(parts.count)
            for part in parts {
                guard let value = UInt8(String(part)) else {
                    throw KeystoreError.invalidSignInput
                }
                bytes.append(value)
            }
            return Data(bytes)
        case .SIGN_MESSAGE_V2_HASHSTRING:
            let data = Data(hex: string)
            if data.isEmpty { throw KeystoreError.invalidSignInput }
            return data
        case .SIGN_MESSAGE_V2_STRING:
            guard let data = string.data(using: .utf8) else {
                throw KeystoreError.invalidSignInput
            }
            return data
        }
    }
    
}
