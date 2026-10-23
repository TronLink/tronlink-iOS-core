
import BigInt
import Foundation

/// Encoding functions
public struct ABIv2Encoder {
    // Bound work for nested/shared input containers just as decoding bounds
    // attacker-controlled lengths and repeated offsets.
    private struct Budget {
        var nodes = 1_000_000
        var typeNodes = 1_000_000
        var payloadBytes = 64 * 1024 * 1024
    }

    
    /// Converts value to BigUInt
    public static func convertToBigUInt(_ value: AnyObject) -> BigUInt? {
        switch value {
        case let v as BigUInt:
            return v
        case let v as BigInt:
            if v.magnitude == 0 { return BigUInt(0) }
            switch v.sign {
            case .minus:
                return nil
            case .plus:
                return v.magnitude
            }
        case let v as String:
            guard let integer = integerString(v), integer.sign != .minus else { return nil }
            return integer.magnitude
        case let v as UInt:
            return BigUInt(v)
        case let v as UInt8:
            return BigUInt(v)
        case let v as UInt16:
            return BigUInt(v)
        case let v as UInt32:
            return BigUInt(v)
        case let v as UInt64:
            return BigUInt(v)
        case let v as Int:
            return v < 0 ? nil : BigUInt(v)
        case let v as Int8:
            return v < 0 ? nil : BigUInt(v)
        case let v as Int16:
            return v < 0 ? nil : BigUInt(v)
        case let v as Int32:
            return v < 0 ? nil : BigUInt(v)
        case let v as Int64:
            return v < 0 ? nil : BigUInt(v)
        default:
            return nil
        }
    }

    /// Converts value to BigInt
    public static func convertToBigInt(_ value: AnyObject) -> BigInt? {
        switch value {
        case let v as BigUInt:
            return BigInt(v)
        case let v as BigInt:
            return v.magnitude == 0 ? BigInt(0) : v
        case let v as String:
            return integerString(v)
        case let v as UInt:
            return BigInt(v)
        case let v as UInt8:
            return BigInt(v)
        case let v as UInt16:
            return BigInt(v)
        case let v as UInt32:
            return BigInt(v)
        case let v as UInt64:
            return BigInt(v)
        case let v as Int:
            return BigInt(v)
        case let v as Int8:
            return BigInt(v)
        case let v as Int16:
            return BigInt(v)
        case let v as Int32:
            return BigInt(v)
        case let v as Int64:
            return BigInt(v)
        default:
            return nil
        }
    }
    
    // BigInt 3.1 accepts empty digit strings as zero. Validate the spelling
    // before conversion, while retaining decimal and unprefixed hex inputs.
    private static func integerString(_ value: String, limitToABIWord: Bool = false) -> BigInt? {
        var digits = value
        let negative = digits.hasPrefix("-")
        if negative || digits.hasPrefix("+") { digits.removeFirst() }
        let radix: Int
        if digits.hasPrefix("0x") || digits.hasPrefix("0X") {
            digits.removeFirst(2)
            radix = 16
        } else if digits.utf8.allSatisfy({ $0 >= 48 && $0 <= 57 }) {
            radix = 10
        } else {
            radix = 16
        }
        guard !digits.isEmpty, digits.utf8.allSatisfy({ byte in
            (byte >= 48 && byte <= 57) ||
                (radix == 16 && ((byte >= 65 && byte <= 70) || (byte >= 97 && byte <= 102)))
        }) else { return nil }
        let significant = digits.drop(while: { $0 == "0" })
        if limitToABIWord, significant.count > (radix == 16 ? 64 : 78) { return nil }
        guard let magnitude = BigUInt(significant.isEmpty ? "0" : String(significant), radix: radix) else { return nil }
        return negative ? -BigInt(magnitude) : BigInt(magnitude)
    }

    /// Converts data to value to solidity data
    public static func convertToData(_ value: AnyObject) -> Data? {
        switch value {
        case let d as Data:
            return d
        case let d as String:
            return d.isHex || d.hasPrefix("0X") ? validatedHexData(d) : d.data(using: .utf8)
        case let d as [UInt8]:
            return Data(d)
        case let d as Web3Address:
            return validatedAddressData(d)
        case let d as [IntegerLiteralType]:
            var bytesArray = [UInt8]()
            for el in d {
                guard el >= 0, el <= 255 else { return nil }
                bytesArray.append(UInt8(el))
            }
            return Data(bytesArray)
        default:
            return nil
        }
    }

    // Preserve this conversion API's left-padding of odd byte strings: 0x1 -> 01.
    // The shared hex decoder requires complete byte pairs.
    private static func validatedHexData(_ value: String) -> Data? {
        var digits = value
        if digits.hasPrefix("0x") || digits.hasPrefix("0X") { digits.removeFirst(2) }
        guard digits.utf8.allSatisfy({ byte in
            (byte >= 48 && byte <= 57) || (byte >= 65 && byte <= 70) || (byte >= 97 && byte <= 102)
        }) else { return nil }
        if digits.utf8.count % 2 != 0 { digits = "0" + digits }
        return Data.fromHex(digits)
    }

    private static func validatedAddressData(_ address: Web3Address) -> Data? {
        // Address strings must supply all 20 bytes; byte-string odd-nibble
        // padding must not silently change a Web3Address's represented value.
        guard case .normal = address.type else { return nil }
        guard address._address.withoutHex.utf8.count == 40,
              let bytes = validatedHexData(address._address), address.isValid else { return nil }
        return bytes
    }
    
    /// Encodes function parameters without the four-byte selector.
    public static func encode(types: [ABIv2.Element.InOut], values: [AnyObject]) -> Data? {
        return encode(types: types.map { $0.type }, values: values)
    }

    /// Encodes function parameters without the four-byte selector.
    public static func encode(types: [ABIv2.Element.ParameterType], values: [AnyObject]) -> Data? {
        var budget = Budget()
        return encodeSequence(types: types, values: values, depth: 0, budget: &budget)
    }

    /// Encodes the value itself. Dynamic values do not include a parent offset.
    /// Use `encode(types: [type], values: [value])` to include that offset.
    public static func encodeSingleType(type: ABIv2.Element.ParameterType, value: AnyObject) -> Data? {
        var budget = Budget()
        return encodeValue(type: type, value: value, depth: 0, budget: &budget)
    }

    // Arrays and tuples use the same head/tail algorithm. Offsets are relative
    // to this sequence; a dynamic array prepends its length to the sequence.
    private static func encodeSequence(types: [ABIv2.Element.ParameterType], values: [AnyObject], depth: Int, budget: inout Budget) -> Data? {
        guard types.count == values.count, types.count <= budget.nodes,
              depth <= ABIv2Layout.maxDepth else { return nil }
        var layouts = [(isStatic: Bool, headSize: UInt64)]()
        var headSize: UInt64 = 0
        for type in types {
            guard let layout = ABIv2Layout.layout(of: type, depth: depth, nodes: &budget.typeNodes) else { return nil }
            let sum = headSize.addingReportingOverflow(layout.headSize)
            guard !sum.overflow, sum.partialValue <= UInt64(Int.max) else { return nil }
            headSize = sum.partialValue
            layouts.append(layout)
        }

        var head = Data()
        var tail = Data()
        for index in types.indices {
            guard let encoded = encodeValue(type: types[index], value: values[index], depth: depth, budget: &budget) else { return nil }
            if layouts[index].isStatic {
                guard UInt64(encoded.count) == layouts[index].headSize else { return nil }
                head.append(encoded)
            } else {
                let offset = headSize.addingReportingOverflow(UInt64(tail.count))
                guard !offset.overflow, offset.partialValue <= UInt64(Int.max),
                      encoded.count <= Int.max - Int(offset.partialValue),
                      let word = unsignedWord(BigUInt(offset.partialValue)) else { return nil }
                head.append(word)
                tail.append(encoded)
            }
        }
        guard UInt64(head.count) == headSize, tail.count <= Int.max - head.count else { return nil }
        head.append(tail)
        return head
    }

    private static func encodeValue(type: ABIv2.Element.ParameterType, value: AnyObject, depth: Int, budget: inout Budget) -> Data? {
        guard budget.nodes > 0,
              ABIv2Layout.layout(of: type, depth: depth, nodes: &budget.typeNodes) != nil else { return nil }
        budget.nodes -= 1
        switch type {
        case let .uint(bits):
            guard let integer = integerForEncoding(value), integer.sign != .minus,
                  integer.magnitude < (BigUInt(1) << Int(bits)) else { return nil }
            return unsignedWord(integer.magnitude)
        case let .int(bits):
            guard let integer = integerForEncoding(value) else { return nil }
            return signedWord(integer, bits: bits)
        case let .fixed(bits, decimals):
            guard let integer = fixedPoint(value, decimals: decimals)?.scaledValue else { return nil }
            return signedWord(integer, bits: bits)
        case let .ufixed(bits, decimals):
            guard let integer = fixedPoint(value, decimals: decimals)?.scaledValue,
                  integer.sign != .minus, integer.magnitude < (BigUInt(1) << Int(bits)) else { return nil }
            return unsignedWord(integer.magnitude)
        case .address:
            let raw: Data
            if let address = value as? Web3Address {
                guard let bytes = validatedAddressData(address) else { return nil }
                raw = bytes
            } else if let string = value as? String {
                let address = Web3Address(string)
                guard let bytes = validatedAddressData(address) else { return nil }
                raw = bytes
            } else if let data = value as? Data {
                raw = data
            } else {
                return nil
            }
            // Share TLCore's validated TRON/EVM address conversion, without
            // changing the existing Address or Web3Address public types.
            guard let address = ABIEncoder.evmAddress20(from: raw) else { return nil }
            return Data(repeating: 0, count: 12) + address
        case .bool:
            guard let boolean = value as? Bool else { return nil }
            return unsignedWord(BigUInt(boolean ? 1 : 0))
        case let .bytes(length):
            guard let bytes = convertToData(value), UInt64(bytes.count) <= length else { return nil }
            return rightPaddedWord(bytes)
        case .function:
            guard let bytes = value as? Data, bytes.count == 24 else { return nil }
            return rightPaddedWord(bytes)
        case .string:
            // Solidity strings are UTF-8 even when their text starts with 0x.
            guard let string = value as? String, string.utf8.count <= budget.payloadBytes,
                  let bytes = string.data(using: .utf8) else { return nil }
            budget.payloadBytes -= bytes.count
            return encodeDynamicBytes(bytes)
        case .dynamicBytes:
            guard let bytes = convertToData(value), bytes.count <= budget.payloadBytes else { return nil }
            budget.payloadBytes -= bytes.count
            return encodeDynamicBytes(bytes)
        case let .array(subtype, length), let .fixedArray(subtype, length):
            let hasLengthWord: Bool
            if case .array(_, 0) = type { hasLengthWord = true } else { hasLengthWord = false }
            guard let elements = value as? [AnyObject], elements.count <= budget.nodes,
                  hasLengthWord || length == UInt64(elements.count) else { return nil }
            let types = Array(repeating: subtype, count: elements.count)
            guard let body = encodeSequence(types: types, values: elements, depth: depth + 1, budget: &budget) else { return nil }
            if hasLengthWord {
                guard body.count <= Int.max - 32, let count = unsignedWord(BigUInt(elements.count)) else { return nil }
                return count + body
            }
            return body
        case let .tuple(types):
            guard let elements = value as? [AnyObject] else { return nil }
            return encodeSequence(types: types, values: elements, depth: depth + 1, budget: &budget)
        }
    }

    // Keep ABI-only bounds checks here rather than changing shared BigInt/Data
    // extensions used by signing, keystore and the other ABI implementation.
    private static func integerForEncoding(_ value: AnyObject) -> BigInt? {
        let integer: BigInt?
        if let string = value as? String {
            integer = integerString(string, limitToABIWord: true)
        } else {
            integer = convertToBigInt(value)
        }
        guard let result = integer, result.magnitude.bitWidth <= 256 else { return nil }
        return result
    }

    private static func fixedPoint(_ value: AnyObject, decimals: UInt64) -> ABIv2.FixedPoint? {
        if let exact = value as? ABIv2.FixedPoint {
            return exact.decimals == decimals ? exact : nil
        }
        if let decimal = value as? String {
            return ABIv2.FixedPoint(decimal, decimals: decimals)
        }
        // Callers must opt into decimal text or an explicitly scaled integer;
        // floating-point and unlabelled integer inputs are ambiguous here.
        return nil
    }

    private static func signedWord(_ value: BigInt, bits: UInt64) -> Data? {
        let limit = BigUInt(1) << Int(bits - 1)
        if value.sign == .minus {
            guard value.magnitude <= limit else { return nil }
            return unsignedWord((BigUInt(1) << 256) - value.magnitude)
        }
        guard value.magnitude < limit else { return nil }
        return unsignedWord(value.magnitude)
    }

    private static func unsignedWord(_ value: BigUInt) -> Data? {
        let bytes = value.serialize()
        guard bytes.count <= 32 else { return nil }
        return Data(repeating: 0, count: 32 - bytes.count) + bytes
    }

    private static func rightPaddedWord(_ bytes: Data) -> Data? {
        guard bytes.count <= 32 else { return nil }
        return bytes + Data(repeating: 0, count: 32 - bytes.count)
    }

    private static func encodeDynamicBytes(_ bytes: Data) -> Data? {
        let padding = (32 - bytes.count % 32) % 32
        guard bytes.count <= Int.max - 32 - padding,
              let length = unsignedWord(BigUInt(bytes.count)) else { return nil }
        return length + bytes + Data(repeating: 0, count: padding)
    }
}

extension ABIv2 {
    /// Exact value for fixedMxN/ufixedMxN, equal to scaledValue / 10^decimals.
    /// Encoding accepts this value or decimal text (never Double/Float).
    /// Decoding returns this type, preserving all ABI integer precision.
    public struct FixedPoint: Equatable, CustomStringConvertible {
        public let scaledValue: BigInt
        public let decimals: UInt64

        public init?(scaledValue: BigInt, decimals: UInt64) {
            guard decimals >= 1, decimals <= 80, scaledValue.magnitude.bitWidth <= 256 else { return nil }
            self.scaledValue = BigInt(sign: scaledValue.sign, magnitude: scaledValue.magnitude)
            self.decimals = decimals
        }

        /// Decimal notation with an optional sign and fraction. No exponent,
        /// hex, whitespace or rounding; extra fractional digits must be zero.
        public init?(_ decimal: String, decimals: UInt64) {
            guard decimals >= 1, decimals <= 80 else { return nil }
            var text = decimal
            let negative = text.hasPrefix("-")
            if negative || text.hasPrefix("+") { text.removeFirst() }
            let parts = text.split(separator: ".", omittingEmptySubsequences: false)
            guard parts.count == 1 || parts.count == 2,
                  parts.allSatisfy({ !$0.isEmpty && $0.utf8.allSatisfy({ $0 >= 48 && $0 <= 57 }) }) else { return nil }
            let precision = Int(decimals)
            let fraction = parts.count == 2 ? String(parts[1]) : ""
            guard fraction.dropFirst(precision).allSatisfy({ $0 == "0" }) else { return nil }
            let digits = String(parts[0]) + String(fraction.prefix(precision))
                + String(repeating: "0", count: max(0, precision - fraction.count))
            let significant = digits.drop(while: { $0 == "0" })
            // A 256-bit unsigned integer has at most 78 decimal digits.
            guard significant.count <= 78,
                  let magnitude = BigUInt(significant.isEmpty ? "0" : String(significant), radix: 10) else { return nil }
            self.init(scaledValue: BigInt(sign: negative ? .minus : .plus, magnitude: magnitude), decimals: decimals)
        }

        /// Exact decimal text retaining the declared number of fractional digits.
        public var description: String {
            let digits = scaledValue.magnitude.description
            let precision = Int(decimals)
            let padded = String(repeating: "0", count: max(0, precision + 1 - digits.count)) + digits
            let split = padded.index(padded.endIndex, offsetBy: -precision)
            let sign = scaledValue.sign == .minus ? "-" : ""
            return sign + String(padded[..<split]) + "." + String(padded[split...])
        }
    }
}
