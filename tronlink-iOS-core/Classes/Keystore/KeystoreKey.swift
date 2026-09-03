
import CryptoSwift
import Foundation

/// Key definition.
public struct KeystoreKey {
    /// Ethereum address.
    public var address: Address

    /// Account type.
    public var type: AccountType

    /// Wallet UUID, optional.
    public var id: String?

    /// Key header with encrypted private key and crypto parameters.
    public var crypto: KeystoreKeyHeader

    /// Mnemonic derivation path
    public var derivationPath = Wallet.defaultPath

    /// Key version, must be 3.
    public var version = 3

    /// Creates a new `Key` with a password. Use `generateHDWallet(password:)` when the generated
    /// mnemonic must be returned for backup.
    /// - Throws: `EncryptError.generateKeyPairFail` for `.encryptedKey`; raw secp256k1
    ///   accounts must be initialized with `init(password:key:)`.
    public init(password: String, type: AccountType) throws {
        switch type {
        case .encryptedKey:
            // Raw secp256k1 accounts may only be created from caller-supplied key material.
            // Generating one through Security.framework would produce a P-256 key instead.
            throw EncryptError.generateKeyPairFail
        case .hierarchicalDeterministicWallet:
            self = try KeystoreKey.generateHDWallet(password: password).key
        }
    }

    /// Creates an HD key and returns its mnemonic without retaining the plaintext in the key.
    public static func generateHDWallet(password: String) throws -> (key: KeystoreKey, mnemonic: String) {
        let mnemonic = try Mnemonic.generate(strength: 128)
        let key = try KeystoreKey(password: password, mnemonic: mnemonic)
        return (key, mnemonic)
    }

    /// Initializes a `Key` from a JSON wallet.
    public init(contentsOf url: URL) throws {
        let data = try Data(contentsOf: url)
        self = try JSONDecoder().decode(KeystoreKey.self, from: data)
    }

    /// Initializes a `Key` by encrypting a private key with a password.
    ///
    /// - Important: `key` must be exactly 32 bytes and a scalar in the secp256k1 range
    ///   `1..<curveOrder`.
    public init(password: String, key: Data) throws {
        guard key.count == 32, EthereumCrypto.isValidPrivateKey(key) else {
            throw EncryptError.invalidPrivateKey
        }

        id = UUID().uuidString.lowercased()
        crypto = try KeystoreKeyHeader(password: password, data: key)

        let pubKey = EthereumCrypto.getPublicKey(from: key)
        address = try KeystoreKey.decodeAddress(from: pubKey)
        type = .encryptedKey
    }

    /// Initializes a `Key` by encrypting a mnemonic phrase with a password.
    public init(password: String, mnemonic: String, passphrase: String = "", derivationPath: String = Wallet.defaultPath) throws {
        id = UUID().uuidString.lowercased()

        var data = try KeystoreKey.makeMnemonicPayload(mnemonic: mnemonic, passphrase: passphrase)
        defer {
            data.resetBytes(in: 0 ..< data.count)
        }
        crypto = try KeystoreKeyHeader(password: password, data: data)

        let key = try Wallet(mnemonic: mnemonic, passphrase: passphrase, path: derivationPath).getKey(at: 0)
        let pubKey = key.publicKey
        address = try KeystoreKey.decodeAddress(from: pubKey)
        type = .hierarchicalDeterministicWallet
        self.derivationPath = derivationPath
    }

    /// Builds the payload encrypted for an HD wallet: the mnemonic as NUL-terminated ASCII
    /// followed by the passphrase as UTF-8.
    static func makeMnemonicPayload(mnemonic: String, passphrase: String) throws -> Data {
        guard let cstring = mnemonic.cString(using: .ascii) else {
            throw EncryptError.invalidMnemonic
        }
        var data = Data(bytes: cstring.map({ UInt8(bitPattern: $0) }))
        data.append(contentsOf: Array(passphrase.utf8))
        return data
    }

    /// Splits a decrypted HD payload back into its mnemonic and passphrase. Keys written before
    /// the passphrase was persisted end at the NUL terminator and yield an empty passphrase.
    static func splitMnemonicPayload(_ data: Data) throws -> (mnemonic: String, passphrase: String) {
        let parts = data.split(separator: 0, maxSplits: 1, omittingEmptySubsequences: false)
        guard let mnemonicData = parts.first,
            let mnemonic = String(data: mnemonicData, encoding: .ascii),
            !mnemonic.isEmpty else {
            throw EncryptError.invalidMnemonic
        }
        guard parts.count > 1 else {
            return (mnemonic, "")
        }
        guard let passphrase = String(data: parts[1], encoding: .utf8) else {
            throw EncryptError.invalidMnemonic
        }
        return (mnemonic, passphrase)
    }

    /// Decodes an Ethereum address from a public key.
    ///
    /// - Throws: `DecryptError.invalidPublicKey` if the key is not an uncompressed secp256k1
    ///   point. `EthereumCrypto` reports failure as an empty `Data` because its return type is
    ///   `nonnull`, so an unchecked result would reach here.
    static func decodeAddress(from publicKey: Data) throws -> Address {
        guard publicKey.count == 65, publicKey.first == 4 else {
            throw DecryptError.invalidPublicKey
        }
        let sha3 = publicKey.dropFirst().sha3(.keccak256)
        var data = Data(hex: "41")
        data.append(sha3[12..<32])
        return Address(data: data)
    }

    /// Decrypts the key and returns the private key.
    public func decrypt(password: String) throws -> Data {
        let derivedKey: Data
        switch crypto.kdf {
        case "scrypt":
            let scrypt = Scrypt(params: crypto.kdfParams)
            derivedKey = try scrypt.calculate(password: password)
        default:
            throw DecryptError.unsupportedKDF
        }

        let mac = KeystoreKey.computeMAC(prefix: derivedKey[derivedKey.count - 16 ..< derivedKey.count], key: crypto.cipherText)
        if mac != crypto.mac {
            throw DecryptError.invalidPassword
        }

        let decryptionKey = derivedKey[0...15]
        let decryptedPK: [UInt8]
        switch crypto.cipher {
        case "aes-128-ctr":
            let aesCipher = try AES(key: decryptionKey.bytes, blockMode: CTR(iv: crypto.cipherParams.iv.bytes), padding: .noPadding)
            decryptedPK = try aesCipher.decrypt(crypto.cipherText.bytes)
        case "aes-128-cbc":
            let aesCipher = try AES(key: decryptionKey.bytes, blockMode: CBC(iv: crypto.cipherParams.iv.bytes), padding: .noPadding)
            decryptedPK = try aesCipher.decrypt(crypto.cipherText.bytes)
        default:
            throw DecryptError.unsupportedCipher
        }

        return Data(bytes: decryptedPK)
    }

    static func computeMAC(prefix: Data, key: Data) -> Data {
        var data = Data(capacity: prefix.count + key.count)
        data.append(prefix)
        data.append(key)
        return data.sha3(.keccak256)
    }

    /// Signs a hash with the given password.
    ///
    /// - Parameters:
    ///   - hash: hash to sign
    ///   - password: key password
    /// - Returns: signature
    /// - Throws: `DecryptError` or `Secp256k1Error`
    public func sign(hash: Data, password: String) throws -> Data {
        var key = try privateKey(password: password)
        defer {
            // Clear memory after signing
            key.resetBytes(in: 0..<key.count)
        }
        return try KeystoreKey.checkedSignature(EthereumCrypto.sign(hash: hash, privateKey: key))
    }

    /// Decrypts the key and derives the private key used by account operations. The caller owns the result and
    /// is responsible for clearing it.
    func privateKey(password: String) throws -> Data {
        switch type {
        case .encryptedKey:
            var secret = try decrypt(password: password)
            // Compatibility with keystores written by an older release when an HD keystore was
            // imported through the raw-private-key path: the payload is the mnemonic (>32 bytes)
            // and only its first 32 bytes ever defined this key's address and signatures.
            // `EthereumCrypto` now requires exactly 32 bytes, so keep using them.
            guard secret.count > 32 else {
                return secret
            }
            let key = Data(secret.prefix(32))
            secret.resetBytes(in: 0 ..< secret.count)
            return key
        case .hierarchicalDeterministicWallet:
            var decrypted = try decrypt(password: password)
            defer {
                decrypted.resetBytes(in: 0 ..< decrypted.count)
            }
            let (mnemonic, passphrase) = try KeystoreKey.splitMnemonicPayload(decrypted)
            return try Wallet(mnemonic: mnemonic, passphrase: passphrase, path: derivationPath).getKey(at: 0).privateKey
        }
    }

    /// `EthereumCrypto` reports failure as an empty `Data` because its return type is `nonnull`.
    /// An unchecked result would be handed to callers as a valid signature.
    private static func checkedSignature(_ signature: Data) throws -> Data {
        guard signature.count == 65 else {
            throw DecryptError.invalidSignature
        }
        return signature
    }

    /// Signs multiple hashes with the given password.
    ///
    /// - Parameters:
    ///   - hashes: array of hashes to sign
    ///   - password: key password
    /// - Returns: [signature]
    /// - Throws: `DecryptError` or `Secp256k1Error`
    public func signHashes(_ hashes: [Data], password: String) throws -> [Data] {
        var key = try privateKey(password: password)
        defer {
            // Clear memory after signing
            key.resetBytes(in: 0..<key.count)
        }
        return try hashes.map({ try KeystoreKey.checkedSignature(EthereumCrypto.sign(hash: $0, privateKey: key)) })
    }
}

public enum DecryptError: Error {
    case unsupportedKDF
    case unsupportedCipher
    case invalidCipher
    case invalidPassword
    case missingAccountKey
    case invalidPublicKey
    case invalidSignature
}

public enum EncryptError: Error {
    case invalidMnemonic
    /// Raw secp256k1 key generation is unsupported; callers must supply imported key material.
    case generateKeyPairFail
    /// Retained for source compatibility with clients of the former Security.framework path.
    case extractPrivateKeyFail
    /// Raw private-key input is not a 32-byte scalar in the secp256k1 range `1..<curveOrder`.
    case invalidPrivateKey
}

extension KeystoreKey: Codable {
    enum CodingKeys: String, CodingKey {
        case address
        case type
        case id
        case crypto
        case derivationPath
        case version
    }

    enum UppercaseCodingKeys: String, CodingKey {
        case crypto = "Crypto"
    }

    struct TypeString {
        static let privateKey = "private-key"
        static let mnemonic = "mnemonic"
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let altValues = try decoder.container(keyedBy: UppercaseCodingKeys.self)

        address = Address(data: try values.decodeHexString(forKey: .address))
        switch try values.decodeIfPresent(String.self, forKey: .type) {
        case TypeString.mnemonic?:
            type = .hierarchicalDeterministicWallet
            derivationPath = try values.decodeIfPresent(String.self, forKey: .derivationPath) ?? Wallet.defaultPath
        default:
            type = .encryptedKey
        }

        id = try values.decode(String.self, forKey: .id)
        if let crypto = try? values.decode(KeystoreKeyHeader.self, forKey: .crypto) {
            self.crypto = crypto
        } else {
            // Workaround for myEtherWallet files
            self.crypto = try altValues.decode(KeystoreKeyHeader.self, forKey: .crypto)
        }
        version = try values.decode(Int.self, forKey: .version)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(address.description.drop0x, forKey: .address)
        switch type {
        case .encryptedKey:
            try container.encode(TypeString.privateKey, forKey: .type)
        case .hierarchicalDeterministicWallet:
            try container.encode(TypeString.mnemonic, forKey: .type)
            try container.encode(derivationPath, forKey: .derivationPath)
        }
        try container.encode(id, forKey: .id)
        try container.encode(crypto, forKey: .crypto)
        try container.encode(version, forKey: .version)
    }
}
