
import Foundation

/// A hierarchical deterministic wallet.
public class Wallet {
//    public static let defaultPath = "m/44'/195'/x'"
    public static let defaultPath = "m/44'/195'/0'/0/0"

    /// Wallet seed. Keep it private and clear it as soon as the wallet is no longer needed.
    private var seed: Data?
    private let seedLock = NSLock()

    /// Derivation path.
    public var path: String

    /// Initializes a wallet from a mnemonic string and a passphrase.
    public init(mnemonic: String, passphrase: String = "", path: String = Wallet.defaultPath) throws {
        seed = try Mnemonic.deriveSeed(mnemonic: mnemonic, passphrase: passphrase)
        self.path = path
    }

    deinit {
        clearSeed()
    }

    /// Initializes a wallet from a mnemonic string and a passphrase.
    public convenience init(mnemonic: String, newPassphrase: String) throws {
        try self.init(mnemonic: mnemonic, passphrase: newPassphrase, path: Wallet.defaultPath)
    }

    private func getDerivationPath(for index: Int) throws -> DerivationPath {
        guard let path = DerivationPath(path.replacingOccurrences(of: "x", with: String(index))) else {
            throw Error.invalidDerivationPath
        }
        return path
    }

    private func getNode(for derivationPath: DerivationPath) throws -> HDNode {
        seedLock.lock()
        defer { seedLock.unlock() }

        guard seed != nil else {
            throw Error.cleared
        }
        var node = HDNode()
        // On failure the node is left zeroed with a NULL curve, which the derivation and
        // public-key calls below would dereference.
        let result = seed!.withUnsafeBytes { (seedPtr: UnsafeRawBufferPointer) -> Int32 in
            hdnode_from_seed(seedPtr.bindMemory(to: UInt8.self).baseAddress, Int32(seedPtr.count), "secp256k1", &node)
        }
        guard result == 1 else {
            throw Error.invalidSeed
        }
        for index in derivationPath.indices {
            guard hdnode_private_ckd(&node, index.derivationIndex) == 1 else {
                throw Error.keyDerivationFailed
            }
        }
        return node
    }

    /// Generates the key at the specified derivation path index.
    ///
    /// - Throws: `Wallet.Error`
    public func getKey(at index: Int) throws -> HDKey {
        let node = try getNode(for: try getDerivationPath(for: index))
        return HDKey(node: node)
    }

    /// Clears the retained seed. The wallet cannot derive more keys afterwards.
    public func clear() {
        clearSeed()
    }

    private func clearSeed() {
        seedLock.lock()
        defer { seedLock.unlock() }

        guard let count = seed?.count else {
            return
        }
        seed?.resetBytes(in: 0 ..< count)
        seed = nil
    }
}

extension Wallet {
    public enum Error: Swift.Error {
        case invalidDerivationPath
        case invalidSeed
        case keyDerivationFailed
        case cleared
    }
}
