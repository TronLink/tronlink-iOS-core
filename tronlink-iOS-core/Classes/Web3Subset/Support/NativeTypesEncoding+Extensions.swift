
import BigInt
import Foundation

public extension Data {
    /// Sets data.count to toBytes and fills missing bytes at the start of the data
    /// - Parameter toBytes: Desired data size
    /// - Parameter isNegative: Fills with ff if negative. default: false
    /// - Returns: Data with desired size
    func setLengthLeft(_ toBytes: UInt64, isNegative: Bool = false) -> Data? {
        let existingLength = UInt64(count)
        if existingLength == toBytes {
            return Data(self)
        } else if existingLength > toBytes {
            return nil
        }
        var data: Data
        if isNegative {
            data = Data(repeating: UInt8(255), count: Int(toBytes - existingLength))
        } else {
            data = Data(repeating: UInt8(0), count: Int(toBytes - existingLength))
        }
        data.append(self)
        return data
    }

    /// Sets data.count to toBytes and fills missing bytes at the end of the data
    /// - Parameter toBytes: Desired data size
    /// - Parameter isNegative: Fills with ff if negative. default: false
    /// - Returns: Data with desired size
    func setLengthRight(_ toBytes: UInt64, isNegative: Bool = false) -> Data? {
        let existingLength = UInt64(count)
        if existingLength == toBytes {
            return Data(self)
        } else if existingLength > toBytes {
            return nil
        }
        var data: Data = Data()
        data.append(self)
        if isNegative {
            data.append(Data(repeating: UInt8(255), count: Int(toBytes - existingLength)))
        } else {
            data.append(Data(repeating: UInt8(0), count: Int(toBytes - existingLength)))
        }
        return data
    }
}

public extension BigInt {
    /// Converts int to data
    func toTwosComplement() -> Data {
        if sign == BigInt.Sign.plus {
            return magnitude.serialize()
        } else {
            let serializedLength = magnitude.serialize().count
            let MAX = BigUInt(1) << (serializedLength * 8)
            let twoComplement = MAX - magnitude
            return twoComplement.serialize()
        }
    }

    /// Encodes a signed ABI integer using exactly bits / 8 bytes.
    /// The width must be a multiple of 8 in 8...256.
    /// - Returns: nil for an invalid width or a value outside the signed range.
    ///   Callers must handle the optional result.
    func abiEncode(bits: UInt64) -> Data! {
        guard bits <= 256 else { return nil }
        do {
            try ABIValue.validateSignedInteger(self, bits: Int(bits))
        } catch {
            return nil
        }
        // Compute the complement at the requested width. A minimal complement
        // can lose leading zero bytes before sign extension (e.g. -65535).
        let encoded = sign == .minus && !isZero
            ? (BigUInt(1) << Int(bits)) - magnitude
            : magnitude
        return encoded.serialize().setLengthLeft(bits / 8)
    }

    /// Converts data to BigInt
    static func fromTwosComplement(data: Data) -> BigInt {
        let isPositive = ((data[0] & 128) >> 7) == 0
        if isPositive {
            let magnitude = BigUInt(data)
            return BigInt(magnitude)
        } else {
            let MAX = (BigUInt(1) << (data.count * 8))
            let magnitude = MAX - BigUInt(data)
            let bigint = BigInt(0) - BigInt(magnitude)
            return bigint
        }
    }
}

public extension BigUInt {
    /// - Returns: Fixed size data of number
    func abiEncode(bits: UInt64) -> Data? {
        let data = serialize()
        let paddedLength = UInt64(ceil((Double(bits) / 8.0)))
        let padded = data.setLengthLeft(paddedLength)
        return padded
    }
}
