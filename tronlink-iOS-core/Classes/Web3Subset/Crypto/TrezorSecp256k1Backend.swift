import Foundation

enum TrezorSecp256k1Backend {
    static func verifyPrivateKey(_ privateKey: Data) -> Bool {
        return EthereumCrypto.isValidPrivateKey(privateKey)
    }

    static func privateToPublic(_ privateKey: Data, compressed: Bool) -> Data? {
        let publicKey = EthereumCrypto.getPublicKey(from: privateKey, compressed: compressed)
        return publicKey.count == (compressed ? 33 : 65) ? publicKey : nil
    }

    static func sign(hash: Data, privateKey: Data) -> Data? {
        let signature = EthereumCrypto.sign(hash: hash, privateKey: privateKey)
        return signature.count == 65 ? signature : nil
    }

    static func recover(hash: Data,
                        signature: Data,
                        recoveryID: UInt8,
                        compressed: Bool) -> Data? {
        let publicKey = EthereumCrypto.recoverPublicKey(
            hash: hash,
            signature: signature,
            recoveryID: recoveryID,
            compressed: compressed
        )
        return publicKey.count == (compressed ? 33 : 65) ? publicKey : nil
    }

    static func uncompressPublicKey(_ publicKey: Data) -> Data? {
        let uncompressed = EthereumCrypto.uncompressPublicKey(publicKey)
        return uncompressed.count == 65 ? uncompressed : nil
    }
}
