
import Foundation
import CryptoSwift

extension Data {
    /// - Returns: keccak256 hash of data
    public func keccak256() -> Data {
        return self.sha3(.keccak256)
    }
}
