
import Foundation
//import CryptoSwift


/// Data errors
public enum DataError: Error {
    /// Throws if data cannot be converted to string
    case hexStringCorrupted(String)
    /// Printable / user displayable description
    public var localizedDescription: String {
        switch self {
        case let .hexStringCorrupted(string):
            return "Cannot convert hex string \"\(string)\" to data"
        }
    }
}

public extension Data {
    /// Inits with array of type
    init<T>(fromArray values: [T]) {
        var values = values
        self.init(buffer: UnsafeBufferPointer(start: &values, count: values.count))
    }
    /// Represents data as array of type
    func toArray<T>(type _: T.Type) -> [T] {
        return withUnsafeBytes {
            [T](UnsafeBufferPointer(start: $0, count: self.count / MemoryLayout<T>.stride))
        }
    }

    /// Constant time comparsion between two data objects
    /// - seealso: [https://codahale.com/a-lesson-in-timing-attacks/](https://codahale.com/a-lesson-in-timing-attacks/)
    func constantTimeComparisonTo(_ other: Data?) -> Bool {
        guard let rhs = other else { return false }
        guard count == rhs.count else { return false }
        var difference = UInt8(0x00)
        for i in 0 ..< count { // compare full length
            difference |= self[i] ^ rhs[i] // constant time
        }
        return difference == UInt8(0x00)
    }

    /// Replaces all data bytes with zeroes.
	///
    /// This one needs because if data deinits, it still will stay in the memory until the override.
	///
	/// webswift uses that to clear private key from memory.
    /// - Parameter data: Data to be cleared
    static func zero(_ data: inout Data) {
        let count = data.count
        data.withUnsafeMutableBytes { (dataPtr: UnsafeMutablePointer<UInt8>) in
            dataPtr.initialize(repeating: 0, count: count)
        }
    }
    
    /// - Parameter length: Desired data length
    /// - Returns: Random data
    /// - Important: Traps if the system CSPRNG fails. Current wallet callers derive
    /// key material, so falling back to another generator would silently swap their
    /// entropy source with no way for the caller to notice.
    static func random(length: Int) -> Data {
        precondition(length >= 0, "Data.random: length must not be negative")
        guard length > 0 else { return Data() }
        var data = Data(repeating: 0, count: length)
        let status = data.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, length, $0)
        }
        guard status == errSecSuccess else {
            fatalError("Data.random: SecRandomCopyBytes failed with status \(status)")
        }
        // Short random values can legitimately be all zero with meaningful probability.
        // Wallet callers request at least 16 bytes, where an all-zero result is a useful
        // low-false-positive signal that the generator is broken.
        // ponytail: only key-sized all-zero output is caught here. A real continuous
        // health test belongs in one shared wallet layer, not in this extension.
        guard length < 16 || data.contains(where: { $0 != 0 }) else {
            fatalError("Data.random: CSPRNG returned an all-zero buffer")
        }
        return data
    }
    
    /// - Parameter separateEvery: Position where separator should be inserted.
    /// Counts per byte (not per character)
    /// - Parameter separator: Separator string
    /// - Returns: Hex representation of data
    func hex(separateEvery: Int, separator: String = " ") -> String {
        var string = ""
        string.reserveCapacity(count*2+count/separateEvery*separator.count)
        var separateCount = separateEvery
        withUnsafeBytes { (bytes: UnsafePointer<UInt8>) in
            for i in 0..<count {
                string += bytes[i].hex
                separateCount -= 1
                if separateCount == 0 {
                    separateCount = separateEvery
                    string += separator
                }
            }
        }
        return string
    }
    
    /// - Returns: Data if string is in hex format
    /// Format: "0x0ba98fc797cfab9864bfac988fa", "0ba98fc797cfab9864bfac988fa"
    static func fromHex(_ hex: String) -> Data? {
        let string = hex.lowercased().withoutHex
        guard let data = Data(hexString: string) else { return nil }
        if data.count == 0 {
            if string == "" {
                return Data()
            } else {
                return nil
            }
        }
        return data
    }
    
    /// - Returns: String (if its utf8 convertible) or hex string
    var string: String {
        return String(data: self, encoding: .utf8) ?? hex
    }
    
    
    /// - Returns: Number bits
    /// - Important: Returns max of 8 bytes for simplicity
    func bitsInRange(_ startingBit: Int, _ length: Int) -> UInt64 {
        let bytes = self[(startingBit / 8) ..< (startingBit + length + 7) / 8]
        let padding = Data(repeating: 0, count: 8 - bytes.count)
        let padded = bytes + padding
        var uintRepresentation = UInt64(bigEndian: padded.withUnsafeBytes { $0.pointee })
        uintRepresentation <<= startingBit % 8
        uintRepresentation >>= UInt64(64 - length)
        return uintRepresentation
    }
}

extension UInt8 {
    /// - Returns: Byte as hex string (from "00" to "ff")
    public var hex: String {
        if self < 0x10 {
            return "0" + String(self, radix: 16)
        } else {
            return String(self, radix: 16)
        }
    }
}
