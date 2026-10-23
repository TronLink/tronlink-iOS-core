

// Hierarchical deterministic key.
public class HDKey {
    var node: HDNode

    init(node: inout HDNode) {
        self.node = node
    }

    deinit {
        withUnsafeMutableBytes(of: &node) {
            memzero($0.baseAddress, $0.count)
        }
    }

    /// The key's address.
    public var address: Address {
        var addressData = Data(repeating: 0, count: 20)
        _ = addressData.withUnsafeMutableBytes { addrPtr in
            hdnode_get_ethereum_pubkeyhash(&node, addrPtr)
        }
        return Address(data: addressData)
    }

    /// Private key data.
    public var privateKey: Data {
        return withUnsafeBytes(of: &node.private_key) { Data($0) }
    }

    /// Public key data.
    public var publicKey: Data {
        var key = Data(repeating: 0, count: 65)
        let params = node.curve.pointee.params
        withUnsafeBytes(of: &node.private_key) { ptr in
            key.withUnsafeMutableBytes { (keyPtr: UnsafeMutableRawBufferPointer) in
                ecdsa_get_public_key65(params, ptr.bindMemory(to: UInt8.self).baseAddress,
                                       keyPtr.bindMemory(to: UInt8.self).baseAddress)
            }
        }
        return key
    }
}
