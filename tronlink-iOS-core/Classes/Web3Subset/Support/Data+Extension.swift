
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
        self = values.withUnsafeBufferPointer { Data(buffer: $0) }
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
        for (left, right) in zip(self, rhs) { // compare full length, including slices
            difference |= left ^ right // no early exit for mismatched bytes
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
    
    
    /// Reads up to 64 bits, most-significant bit first, relative to this Data's startIndex.
    /// - Precondition: The nonnegative range must lie within this Data and length must be 0...64.
    /// Use `bitsInRangeIfValid` when the range comes from untrusted input.
    func bitsInRange(_ startingBit: Int, _ length: Int) -> UInt64 {
        guard let value = bitsInRangeIfValid(startingBit, length) else {
            preconditionFailure("Bit range must lie within Data and contain at most 64 bits")
        }
        return value
    }

    /// Returns nil for an invalid range; an empty range at any valid position returns zero.
    /// Bit zero is the most-significant bit of the byte at startIndex, including for slices.
    func bitsInRangeIfValid(_ startingBit: Int, _ length: Int) -> UInt64? {
        guard startingBit >= 0, length >= 0, length <= 64 else { return nil }
        let firstByte = startingBit / 8
        let bitOffset = startingBit % 8
        guard firstByte <= count else { return nil }
        if length == 0 {
            return firstByte < count || bitOffset == 0 ? 0 : nil
        }

        // These sums are bounded by 78. Avoid overflowing count * 8 or startingBit + length.
        let requiredBytes = (bitOffset + length + 7) / 8
        guard requiredBytes <= count - firstByte else { return nil }

        // A 64-bit field can span nine source bytes. Byte reads also avoid UInt64 alignment
        // assumptions and leave the original data, byte order and slice indices untouched.
        var value: UInt64 = 0
        for offset in 0..<length {
            let bit = bitOffset + offset
            let byteIndex = index(startIndex, offsetBy: firstByte + bit / 8)
            let nextBit = (self[byteIndex] >> (7 - bit % 8)) & 1
            value = (value << 1) | UInt64(nextBit)
        }
        return value
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
