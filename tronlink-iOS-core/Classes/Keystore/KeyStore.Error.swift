
import Foundation

extension KeyStore {
    public enum Error: Swift.Error, LocalizedError {
        case accountAlreadyExists
        case accountNotFound
        case invalidMnemonic
        /// The address declared inside the keystore JSON does not match the address that can be
        /// derived from the decrypted secret. Indicates a tampered or mis-typed keystore.
        case invalidKey

        public var errorDescription: String? {
            switch self {
            case .accountAlreadyExists:
                return NSLocalizedString("Account already exists", comment: "Error message when trying to add an account that already exists")
            case .accountNotFound:
                return NSLocalizedString("Account not found", comment: "Error message when trying to access an account that does not exist")
            case .invalidMnemonic:
                return NSLocalizedString("Invalid mnemonic phrase", comment: "Error message when trying to import an invalid mnemonic phrase")
            case .invalidKey:
                return NSLocalizedString("Invalid keystore: address does not match decrypted key", comment: "Error message when the address declared in a keystore JSON does not match the address derived from the decrypted secret")
            }
        }
    }
}
