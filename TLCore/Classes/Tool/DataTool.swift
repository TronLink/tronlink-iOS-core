
import Foundation
import CryptoSwift

public extension Data {
    var hex: String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
    
    var hexEncoded: String {
        return "0x" + self.hex
    }
    
    func toString() -> String? {
        return String(data: self, encoding: .utf8)
    }
    
    var addressString: String {
        return String(base58CheckEncoding: self)
    }
    
    func sha256T() -> Data {
      Data(Digest.sha256(bytes))
    }
    
    var bytesT: Array<UInt8> {
      Array(self)
    }
}
