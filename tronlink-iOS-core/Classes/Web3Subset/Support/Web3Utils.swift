import Foundation

public class Web3Utils {
}

/// Various units used in Ethereum ecosystem
public enum Web3Units: Int {
    /// 18 decimals
    case eth = 18
    /// 0 decimals
    case wei = 0
    /// 3 decimals
    case kWei = 3
    /// 6 decimals
    case mWei = 6
    /// 9 decimals
    case gWei = 9
    /// 12 decimals
    case microEther = 12
    /// 15 decimals
    case finney = 15
    /// Returns number of decimals (same as .rawValue)
    public var decimals: Int {
        return rawValue
    }
}

public enum Web3UtilsError: Error {
    case cannotConvertDataToAscii
    case invalidSignatureLength

    public var localizedDescription: String {
        switch self {
        case .cannotConvertDataToAscii:
            return "Cannot convert provided data to ascii string"
        case .invalidSignatureLength:
            return "Invalid signature length: Signature size should be 65 bytes"
        }
    }
}

public enum PublicKeyToAddressError: Error {
    case shouldStartWith4
    case invalidPublicKeySize

    public var localizedDescription: String {
        switch self {
        case .shouldStartWith4:
            return "Public key should start with 0x04"
        case .invalidPublicKeySize:
            return "Public key must be 64 bytes long"
        }
    }
}

extension Web3Utils {
    public static func privateToPublic(_ privateKey: Data, compressed: Bool = false) throws -> Data {
        return try SECP256K1.privateToPublic(privateKey: privateKey, compressed: compressed)
    }

    public static func publicToAddressData(_ publicKey: Data) throws -> Data {
        if publicKey.count == 33 {
            var parsedPublicKey = try SECP256K1.parsePublicKey(serializedKey: publicKey)
            let decompressedKey = try SECP256K1.serializePublicKey(publicKey: &parsedPublicKey, compressed: false)
            return try publicToAddressData(decompressedKey)
        } else {
            var stipped = publicKey
            if stipped.count == 65 {
                guard stipped[0] == 4 else { throw PublicKeyToAddressError.shouldStartWith4 }
                stipped = stipped[1 ... 64]
            }
            guard stipped.count == 64 else { throw PublicKeyToAddressError.invalidPublicKeySize }
            let sha3 = stipped.keccak256()
            let addressData = sha3[12 ..< 32]
            return addressData
        }
    }

    public static func publicToAddress(_ publicKey: Data) throws -> Web3Address {
        let addressData = try Web3Utils.publicToAddressData(publicKey)
        let address = addressData.hex
        return Web3Address(address)
    }

    public static func publicToAddressString(_ publicKey: Data) throws -> String {
        let addressData = try Web3Utils.publicToAddressData(publicKey)
        let address = addressData.hex.withHex.lowercased()
        return address
    }

    public static func addressDataToString(_ addressData: Data) throws -> String {
        return Web3Address(addressData)._address
    }

    public static func hashPersonalMessage(_ personalMessage: Data) throws -> Data {
        var prefix = "\u{19}Ethereum Signed Message:\n"
        prefix += String(personalMessage.count)
        guard let prefixData = prefix.data(using: .ascii) else { throw Web3UtilsError.cannotConvertDataToAscii }
        var data = Data()
        if personalMessage.count >= prefixData.count && prefixData == personalMessage[0 ..< prefixData.count] {
            data.append(personalMessage)
        } else {
            data.append(prefixData)
            data.append(personalMessage)
        }
        return data.keccak256()
    }

    public static func personalECRecover(_ personalMessage: String, signature: String) throws -> Web3Address {
        return try Web3Utils.personalECRecover(personalMessage.dataFromHex(), signature: signature.dataFromHex())
    }

    public static func personalECRecover(_ personalMessage: Data, signature: Data) throws -> Web3Address {
        guard signature.count == 65 else { throw Web3UtilsError.invalidSignatureLength }
        let hash = try Web3Utils.hashPersonalMessage(personalMessage)
        let publicKey = try SECP256K1.recoverPublicKey(hash: hash, signature: signature)
        return try Web3Utils.publicToAddress(publicKey)
    }

    public static func getAddressFromSignature(_ personalMessage: Data, signature: String) throws -> Web3Address {
        let signatureData = try signature.dataFromHex()
        guard signatureData.count == 65 else { throw Web3UtilsError.invalidSignatureLength }
        let publicKey = try SECP256K1.recoverPublicKey(hash: personalMessage, signature: signatureData)
        return try Web3Utils.publicToAddress(publicKey)
    }

    public static func hashECRecover(hash: Data, signature: Data) throws -> Web3Address {
        try signature.checkSignatureSize()
        let rData = Array(signature[0 ..< 32])
        let sData = Array(signature[32 ..< 64])
        let vData = signature[64]
        let signatureData = try SECP256K1.marshalSignature(v: vData, r: rData, s: sData)
        let publicKey = try SECP256K1.recoverPublicKey(hash: hash, signature: signatureData)
        return try Web3Utils.publicToAddress(publicKey)
    }

    public static func keccak256(_ data: Data) -> Data? {
        if data.count == 0 { return nil }
        return data.keccak256()
    }

    public static func sha3(_ data: Data) -> Data? {
        if data.count == 0 { return nil }
        return data.keccak256()
    }

    public static func sha256(_ data: Data) -> Data? {
        if data.count == 0 { return nil }
        return data.sha256T()
    }

    static func unmarshalSignature(signatureData: Data) -> SECP256K1.UnmarshaledSignature? {
        if signatureData.count != 65 { return nil }
        let bytes = Array(signatureData)
        let r = Array(bytes[0 ..< 32])
        let s = Array(bytes[32 ..< 64])
        return SECP256K1.UnmarshaledSignature(v: bytes[64], r: r, s: s)
    }

    static func marshalSignature(v: UInt8, r: [UInt8], s: [UInt8]) -> Data? {
        guard r.count == 32, s.count == 32 else { return nil }
        var completeSignature = Data(bytes: r)
        completeSignature.append(Data(bytes: s))
        completeSignature.append(Data(bytes: [v]))
        return completeSignature
    }

    static func marshalSignature(unmarshalledSignature: SECP256K1.UnmarshaledSignature) -> Data {
        var completeSignature = Data(bytes: unmarshalledSignature.r)
        completeSignature.append(Data(bytes: unmarshalledSignature.s))
        completeSignature.append(Data(bytes: [unmarshalledSignature.v]))
        return completeSignature
    }
}
