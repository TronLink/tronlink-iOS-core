
import Foundation

extension Data {
    /// Initializes `Data` from complete hex byte pairs, optionally prefixed with `0x`.
    /// Returns nil for odd-length input or any non-ASCII-hex character.
    public init?(hexString: String) {
        let string: String
        if hexString.hasPrefix("0x") {
            string = String(hexString.dropFirst(2))
        } else {
            string = hexString
        }

        let stringBytes = Array(string.utf8)
        guard stringBytes.count % 2 == 0 else {
            return nil
        }

        self.init(capacity: stringBytes.count / 2)
        for i in stride(from: 0, to: stringBytes.count, by: 2) {
            guard let high = Data.value(of: stringBytes[i]),
                  let low = Data.value(of: stringBytes[i + 1]) else {
                return nil
            }
            append((high << 4) | low)
        }
    }

    /// Converts an ASCII byte to a hex value.
    private static func value(of nibble: UInt8) -> UInt8? {
        switch nibble {
        case UInt8(ascii: "0") ... UInt8(ascii: "9"):
            return nibble - UInt8(ascii: "0")
        case UInt8(ascii: "a") ... UInt8(ascii: "f"):
            return 10 + nibble - UInt8(ascii: "a")
        case UInt8(ascii: "A") ... UInt8(ascii: "F"):
            return 10 + nibble - UInt8(ascii: "A")
        default:
            return nil
        }
    }

    /// Returns the hex string representation of the data.
    public var hexString: String {
        var string = ""
        for byte in self {
            string.append(String(format: "%02x", byte))
        }
        return string
    }
}

public extension KeyedDecodingContainerProtocol {
    func decodeHexString(forKey key: Self.Key) throws -> Data {
        let hexString = try decode(String.self, forKey: key)
        guard let data = Data(hexString: hexString) else {
            throw DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: "Expected hexadecimal string")
        }
        return data
    }

    func decodeHexStringIfPresent(forKey key: Self.Key) throws -> Data? {
        guard let hexString = try decodeIfPresent(String.self, forKey: key) else {
            return nil
        }
        guard let data = Data(hexString: hexString) else {
            throw DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: "Expected hexadecimal string")
        }
        return data
    }
}
