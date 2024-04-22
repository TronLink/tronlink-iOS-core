import Foundation

public enum KeystoreError: LocalizedError {
    case failedToDeleteAccount
    case failedToDecryptKey
    case failedToImport(Error)
    case duplicateAccount
    case failedToSignTransaction
    case failedToUpdatePassword
    case failedToCreateWallet
    case failedToImportPrivateKey
    case invalidPrivateKey
    case failedToParseJSON
    case accountNotFound
    case failedToSignMessage
    case failedToSignTypedMessage
    case failedToExportPrivateKey
    case invalidMnemonicPhrase
    case successToImport
    case invalidKeystore
    case invalidObserver
    case failedToGetKeychain

    public var errorDescription: String? {
        switch self {
        case .failedToDeleteAccount:
            return "Failed to delete account"
        case .failedToDecryptKey:
            return "Could not decrypt key with given passphrase"
        case .failedToImport(let error):
            return error.localizedDescription
        case .duplicateAccount:
            return "You already added this address to wallets"
        case .failedToSignTransaction:
            return "Failed to get account signature data. Please try to re-import this account."
        case .failedToUpdatePassword:
            return "Failed to update password"
        case .failedToCreateWallet:
            return "Failed to create wallet"
        case .failedToImportPrivateKey:
            return "Failed to import private key"
        case .invalidPrivateKey:
            return "Invalid privateKey"
        case .failedToParseJSON:
            return "Failed to parse key JSON"
        case .accountNotFound:
            return "TrustKeystore.Account not found"
        case .failedToSignMessage:
            return "Failed to sign message"
        case .failedToSignTypedMessage:
            return "Failed to sign typed message"
        case .failedToExportPrivateKey:
            return "Failed to export private key"
        case .invalidMnemonicPhrase:
            return "Invalid mnemonic phrase"
        case .successToImport:
            return "sucess to import"
        case .invalidKeystore:
            return "Invalid keystore"
        case .invalidObserver:
            return "Invalid observer"
        case .failedToGetKeychain:
            return "Failed to get account signature data. Please try to re-import this account."
        }
    }
}
