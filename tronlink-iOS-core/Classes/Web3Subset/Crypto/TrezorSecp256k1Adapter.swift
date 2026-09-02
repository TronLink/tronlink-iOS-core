import Foundation

extension Data {
    func checkSignatureSize() throws {
        try checkSignatureSize(compressed: false)
    }

    func checkSignatureSize(compressed: Bool) throws {
        if compressed {
            guard count == 33 else { throw SECP256K1Error.invalidSignatureSize }
        } else {
            guard count == 65 else { throw SECP256K1Error.invalidSignatureSize }
        }
    }

    func checkSignatureSize(maybeCompressed: Bool) throws {
        if maybeCompressed {
            guard count == 65 || count == 33 else { throw SECP256K1Error.invalidSignatureSize }
        } else {
            guard count == 65 else { throw SECP256K1Error.invalidSignatureSize }
        }
    }

    func checkHashSize() throws {
        guard count == 32 else { throw SECP256K1Error.invalidHashSize }
    }

    func checkPrivateKeySize() throws {
        guard count == 32 else { throw SECP256K1Error.invalidPrivateKeySize }
    }

    func checkPublicKeySize() throws {
        guard count == 65 else { throw SECP256K1Error.invalidPublicKeySize }
    }
}

/// Errors for secp256k1
public enum SECP256K1Error: Error {
    /// Signature required 1024 rounds and failed
    case signingFailed
    /// Cannot verify private key
    case invalidPrivateKey
    /// Hash size should be 32 bytes long
    case invalidHashSize
    /// Private key size should be 32 bytes long
    case invalidPrivateKeySize
    /// Signature size should be 65 bytes long
    case invalidSignatureSize
    /// Public key size should be 65 bytes long
    case invalidPublicKeySize
    /// Printable / user displayable description
    public var localizedDescription: String {
        switch self {
        case .signingFailed:
            return "Signature required 1024 rounds and failed"
        case .invalidPrivateKey:
            return "Cannot verify private key"
        case .invalidHashSize:
            return "Hash size should be 32 bytes long"
        case .invalidPrivateKeySize:
            return "Private key size should be 32 bytes long"
        case .invalidSignatureSize:
            return "Signature size should be 65 bytes long"
        case .invalidPublicKeySize:
            return "Public key size should be 65 bytes long"
        }
    }
}

/// Errors for secp256k1
public enum SECP256DataError: Error {
    /// Cannot recover public key
    case cannotRecoverPublicKey
    /// Cannot extract public key from private key
    case cannotExtractPublicKeyFromPrivateKey
    /// Cannot make recoverable signature
    case cannotMakeRecoverableSignature
    /// Optional signing entropy could not be generated
    case cannotGenerateExtraEntropy
    /// Cannot parse signature
    case cannotParseSignature
    /// Cannot parse public key
    case cannotParsePublicKey
    /// Cannot serialize public key
    case cannotSerializePublicKey
    /// Cannot combine public keys
    case cannotCombinePublicKeys
    /// Cannot serialize signature
    case cannotSerializeSignature
    /// Signature corrupted
    case signatureCorrupted
    /// Invalid marshal signature size
    case invalidMarshalSignatureSize
    /// Printable / user displayable description
    public var localizedDescription: String {
        switch self {
        case .cannotRecoverPublicKey:
            return "Cannot recover public key"
        case .cannotExtractPublicKeyFromPrivateKey:
            return "Cannot extract public key from private key"
        case .cannotMakeRecoverableSignature:
            return "Cannot make recoverable signature"
        case .cannotGenerateExtraEntropy:
            return "Cannot generate extra entropy for signing"
        case .cannotParseSignature:
            return "Cannot parse signature"
        case .cannotParsePublicKey:
            return "Cannot parse public key"
        case .cannotSerializePublicKey:
            return "Cannot serialize public key"
        case .cannotCombinePublicKeys:
            return "Cannot combine public keys"
        case .cannotSerializeSignature:
            return "Cannot serialize signature"
        case .signatureCorrupted:
            return "Signature corrupted"
        case .invalidMarshalSignatureSize:
            return "Invalid marshal signature size"
        }
    }
}

struct SECP256K1 {
    struct UnmarshaledSignature {
        var v: UInt8
        var r = [UInt8](repeating: 0, count: 32)
        var s = [UInt8](repeating: 0, count: 32)
    }

    static func normalizedRecoveryID(_ value: UInt8) -> UInt8 {
        return value < 2 ? value : 1 - (value % 2)
    }

    static func verifyPrivateKey(privateKey: Data) throws {
        try privateKey.checkPrivateKeySize()
        guard TrezorSecp256k1Backend.verifyPrivateKey(privateKey) else {
            throw SECP256K1Error.invalidPrivateKey
        }
    }

    static func privateToPublic(privateKey: Data, compressed: Bool = false) throws -> Data {
        try verifyPrivateKey(privateKey: privateKey)
        guard let publicKey = TrezorSecp256k1Backend.privateToPublic(privateKey, compressed: compressed) else {
            throw SECP256DataError.cannotExtractPublicKeyFromPrivateKey
        }
        return publicKey
    }

    static func signForRecovery(hash: Data,
                                privateKey: Data) throws
        -> (serializedSignature: Data, rawSignature: Data) {
        try hash.checkHashSize()
        try verifyPrivateKey(privateKey: privateKey)

        for _ in 0 ... 1024 {
            guard let rawSignature = TrezorSecp256k1Backend.sign(hash: hash, privateKey: privateKey),
                  rawSignature.count == 65,
                  rawSignature[64] <= 1 else {
                continue
            }
            let expectedPublicKey = try privateToPublic(privateKey: privateKey)
            let recoveredPublicKey = try recoverPublicKey(
                hash: hash,
                signature: rawSignature,
                compressed: false
            )
            guard recoveredPublicKey == expectedPublicKey else {
                continue
            }
            return (rawSignature, rawSignature)
        }
        throw SECP256K1Error.signingFailed
    }

    static func recoverPublicKey(hash: Data,
                                 signature: Data,
                                 compressed: Bool = false) throws -> Data {
        try hash.checkHashSize()
        try signature.checkSignatureSize()
        let recoveryID = normalizedRecoveryID(signature[64])
        guard let publicKey = TrezorSecp256k1Backend.recover(
            hash: hash,
            signature: Data(signature.prefix(64)),
            recoveryID: recoveryID,
            compressed: compressed
        ) else {
            throw SECP256DataError.cannotRecoverPublicKey
        }
        return publicKey
    }

    static func recoverSender(hash: Data, signature: Data) throws -> Web3Address {
        let pubKey = try SECP256K1.recoverPublicKey(hash: hash, signature: signature, compressed: false)
        try pubKey.checkPublicKeySize()
        let addressData = Data(pubKey.keccak256()[12 ..< 32])
        return Web3Address(addressData)
    }

    static func unmarshalSignature(signatureData: Data) throws -> UnmarshaledSignature {
        try signatureData.checkSignatureSize()
        let bytes = Array(signatureData)
        let r = Array(bytes[0 ..< 32])
        let s = Array(bytes[32 ..< 64])
        var v = bytes[64]
        if v >= 27 {
            v = v - 27
        }
        guard v <= 3 else { throw SECP256DataError.signatureCorrupted }
        return UnmarshaledSignature(v: v, r: r, s: s)
    }

    static func marshalSignature(v: UInt8, r: [UInt8], s: [UInt8]) throws -> Data {
        guard r.count == 32, s.count == 32 else { throw SECP256DataError.invalidMarshalSignatureSize }
        var completeSignature = Data(bytes: r)
        completeSignature.append(Data(bytes: s))
        completeSignature.append(Data(bytes: [v]))
        return completeSignature
    }

    static func marshalSignature(v: Data, r: Data, s: Data) throws -> Data {
        guard r.count == 32, s.count == 32, v.count == 1 else { throw SECP256DataError.invalidMarshalSignatureSize }
        var completeSignature = Data(r)
        completeSignature.append(s)
        completeSignature.append(v)
        return completeSignature
    }
}
