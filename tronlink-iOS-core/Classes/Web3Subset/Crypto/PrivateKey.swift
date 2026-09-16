
import Foundation
import BigInt

/**
 Secp256k1 private key.
 
 Used in ethereum accounts. You can get public key, address and sign some data
 
 ## Performance
 
 > Operations per second in debug and release build mode
 ```
 Generate Private key:
 release            debug
 175772             160180
 
 PrivateKey -> Public Key:
 release            debug
 26642              9036
 
 PrivateKey -> Web3Address:
 release            debug
 11894              2058
 ```
 */
/// One signing identity. Create a new instance to use a different private key.
public class PrivateKey {
    /// Private key data, fixed for the lifetime of this instance.
    public let privateKey: Data
    
    /// Cached public key derived from this instance's private key.
    public private(set) lazy var publicKey: Data = try! SECP256K1.privateToPublic(privateKey: privateKey)
    
    /// Cached address derived from this instance's public key.
    public private(set) lazy var address: Web3Address = try! Web3Utils.publicToAddress(publicKey)
    
    /// Generates random private key. All generated keys are verified
    public init() {
        self.privateKey = PrivateKey.generatePrivateKey()
    }

    static func generatePrivateKey(using randomBytes: () -> Data = { Data.random(length: 32) }) -> Data {
        while true {
            let privateKey = randomBytes()
            if (try? SECP256K1.verifyPrivateKey(privateKey: privateKey)) != nil {
                return privateKey
            }
        }
    }
    
    /// Init with private key data. run .verify() to verify it
    public init(_ privateKey: Data) {
        self.privateKey = privateKey
    }
    
    
    /// Signs hash with private key signature
    ///
    /// - Parameter hash: 32 bytes hash. To get hash call data.keccak256()
    /// - Returns: Signature that you can use in your transactions
    /// - Throws: If hash size invalid hash size or private key. Call privateKey.verify()
    public func sign(hash: Data) throws -> Signature {
        let signature = try SECP256K1.signForRecovery(hash: hash, privateKey: privateKey).serializedSignature
        return Signature(data: signature)
    }
    
    
    /// Verifies the private key. Also every 32 byte private keys are valid
    ///
    /// - Throws: SECP256K1Error.invalidPrivateKey
    public func verify() throws {
        try SECP256K1.verifyPrivateKey(privateKey: privateKey)
    }
}


/// A 65-byte R || S || recovery-ID signature, as returned by PrivateKey.sign(hash:).
public class Signature {
    /// Signature data
    public let data: Data
    
    /// Creates an unchecked signature. Call check() before using components from custom data.
    ///
    /// - Parameter data: Signature data
    public init(data: Data) {
        self.data = data
    }
    
    
    /// Checks the encoded length and recovery ID, not cryptographic validity.
    ///
    /// - Parameter compressed: Retained for source compatibility. Must be false;
    ///   compressed signatures are not supported and true always throws.
    /// - Throws: SECP256K1Error.invalidSignatureSize or SECP256DataError.signatureCorrupted
    public func check(compressed: Bool = false) throws {
        try data.checkSignatureSize(compressed: compressed)
        guard v < 4 else { throw SECP256DataError.signatureCorrupted }
    }
    
    /// First 32 bytes. Returns zero for an invalid length; call check() before use.
    public lazy var r: BigUInt = {
        guard data.count == 65 else { return BigUInt(0) }
        return BigUInt(data.prefix(32))
    }()
    /// Next 32 bytes. Returns zero for an invalid length; call check() before use.
    public lazy var s: BigUInt = {
        guard data.count == 65 else { return BigUInt(0) }
        return BigUInt(data.dropFirst(32).prefix(32))
    }()
    /// Recovery ID, with 27...30 normalized to 0...3. An invalid length returns
    /// UInt8.max, which is not a valid recovery ID; call check() before use.
    public lazy var v: UInt8 = {
        guard data.count == 65, var v = data.last else { return UInt8.max }
        if v >= 27 {
            v = v - 27
        }
        return v
    }()
}
