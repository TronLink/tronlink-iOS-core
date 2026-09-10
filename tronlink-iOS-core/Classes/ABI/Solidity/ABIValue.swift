
import BigInt
import Foundation

public indirect enum ABIValue {
    /// Unsigned integer with `0 < bits <= 256`, `bits % 8 == 0`
    case uint(bits: Int, BigUInt)

    /// Signed integer with `0 < bits <= 256`, `bits % 8 == 0`
    case int(bits: Int, BigInt)

    /// Address, similar to `uint(bits: 160)`
    case address(Address)

    /// Boolean
    case bool(Bool)

    /// Signed fixed-point decimal number of M bits, `8 <= M <= 256`, `M % 8 == 0`, and `0 < N <= 80`, which denotes the value `v` as `v / (10 ** N)`
    case fixed(bits: Int, Int, BigInt)

    /// Unsigned fixed-point decimal number of M bits, `8 <= M <= 256`, `M % 8 == 0`, and `0 < N <= 80`, which denotes the value `v` as `v / (10 ** N)`
    case ufixed(bits: Int, Int, BigUInt)

    /// Fixed-length bytes
    case bytes(Data)

    /// A function call
    case function(Function, [ABIValue])

    /// Fixed-length array where all values have the same type
    case array(ABIType, [ABIValue])

    /// Dynamic-sized byte sequence
    case dynamicBytes(Data)

    /// String
    case string(String)

    /// Variable-length array where all values have the same type
    case dynamicArray(ABIType, [ABIValue])

    /// Tuple
    case tuple([ABIValue])

    /// Value type
    public var type: ABIType {
        switch self {
        case .uint(let bits, _):
            return .uint(bits: bits)
        case .int(let bits, _):
            return .int(bits: bits)
        case .address:
            return .address
        case .bool:
            return .bool
        case .fixed(let bits, let scale, _):
            return .fixed(bits, scale)
        case .ufixed(let bits, let scale, _):
            return .ufixed(bits, scale)
        case .bytes(let data):
            return .bytes(data.count)
        case .function(let f, _):
            return .function(f)
        case .array(let type, let array):
            return .array(type, array.count)
        case .dynamicBytes:
            return .dynamicBytes
        case .string:
            return .string
        case .dynamicArray(let type, _):
            return .dynamicArray(type)
        case .tuple(let array):
            return .tuple(array.map({ $0.type }))
        }
    }

    /// Encoded length in bytes
    public var length: Int {
        switch self {
        case .uint, .int, .address, .bool, .fixed, .ufixed:
            return 32
        case .bytes(let data):
            return ((data.count + 31) / 32) * 32
        case .function(_, let args):
            return 4 + ABIValue.tupleLength(args)
        case .array(_, let array):
            return ABIValue.tupleLength(array)
        case .dynamicBytes(let data):
            return 32 + ((data.count + 31) / 32) * 32
        case .string(let string):
            let dataLength = string.data(using: .utf8)?.count ?? 0
            return 32 + ((dataLength + 31) / 32) * 32
        case .dynamicArray(_, let array):
            return 32 + ABIValue.tupleLength(array)
        case .tuple(let array):
            return ABIValue.tupleLength(array)
        }
    }

    private static func tupleLength(_ values: [ABIValue]) -> Int {
        // Dynamic members contribute both a head offset and their encoded tail.
        return values.reduce(0, { $0 + ($1.isDynamic ? 32 : 0) + $1.length })
    }

    /// Whether the value is dynamic
    public var isDynamic: Bool {
        switch self {
        case .uint, .int, .address, .bool, .fixed, .ufixed, .bytes:
            return false
        case .dynamicBytes, .string, .dynamicArray:
            return true
        case .array(let type, _):
            return type.isDynamic
        case .function(_, let array):
            return array.contains(where: { $0.isDynamic })
        case .tuple(let array):
            return array.contains(where: { $0.isDynamic })
        }
    }

    /// Creates a value from `Any` and an `ABIType`.
    ///
    /// Short fixed bytes are right-padded to their declared size for compatibility.
    /// - Throws: `ABIError` for invalid types, out-of-range values or mismatched counts.
    public init(_ value: Any, type: ABIType) throws {
        try type.validate()
        switch (type, value) {
        case (.uint(let bits), let value as Int):
            guard value >= 0 else { throw ABIError.integerOverflow }
            self = .uint(bits: bits, BigUInt(value))
        case (.uint(let bits), let value as UInt):
            self = .uint(bits: bits, BigUInt(value))
        case (.uint(let bits), let value as BigUInt):
            self = .uint(bits: bits, value)
        case (.int(let bits), let value as Int):
            self = .int(bits: bits, BigInt(value))
        case (.int(let bits), let value as BigInt):
            self = .int(bits: bits, value)
        case (.address, let address as Address):
            self = .address(address)
        case (.bool, let value as Bool):
            self = .bool(value)
        case (.fixed(let bits, let scale), let value as BigInt):
            self = .fixed(bits: bits, scale, value)
        case (.ufixed(let bits, let scale), let value as BigUInt):
            self = .ufixed(bits: bits, scale, value)
        case (.bytes(let count), let data as Data):
            guard data.count <= count else { throw ABIError.invalidArgumentType }
            self = .bytes(data + Data(repeating: 0, count: count - data.count))
        case (.function(let f), let args as [Any]):
            self = .function(f, try f.castArguments(args))
        case (.array(let type, let count), let array as [Any]):
            guard array.count == count else { throw ABIError.invalidNumberOfArguments }
            self = .array(type, try array.map({ try ABIValue($0, type: type) }))
        case (.dynamicBytes, let data as Data):
            self = .dynamicBytes(data)
        case (.dynamicBytes, let string as String):
            self = .dynamicBytes(string.data(using: .utf8) ?? Data(bytes: Array(string.utf8)))
        case (.string, let string as String):
            self = .string(string)
        case (.dynamicArray(let type), let array as [Any]):
            self = .dynamicArray(type, try array.map({ try ABIValue($0, type: type) }))
        case (.tuple(let types), let array as [Any]):
            guard array.count == types.count else { throw ABIError.invalidNumberOfArguments }
            self = .tuple(try zip(types, array).map({ try ABIValue($1, type: $0) }))
        default:
            throw ABIError.invalidArgumentType
        }
        try validate()
    }

    /// Enum cases are public, so encoding must also validate values built without init(_:type:).
    func validate() throws {
        try type.validate()
        switch self {
        case .uint(let bits, let value), .ufixed(let bits, _, let value):
            guard value.bitWidth <= bits else { throw ABIError.integerOverflow }
        case .int(let bits, let value), .fixed(let bits, _, let value):
            try ABIValue.validateSignedInteger(value, bits: bits)
        case .array(let type, let values), .dynamicArray(let type, let values):
            guard values.allSatisfy({ $0.type == type }) else { throw ABIError.invalidArgumentType }
            for value in values { try value.validate() }
        case .tuple(let values):
            for value in values { try value.validate() }
        case .function(let function, let values):
            guard values.count == function.parameters.count else { throw ABIError.invalidNumberOfArguments }
            for (type, value) in zip(function.parameters, values) {
                guard value.type == type else { throw ABIError.invalidArgumentType }
                try value.validate()
            }
        case .address, .bool, .bytes, .dynamicBytes, .string:
            break
        }
    }

    static func validateSignedInteger(_ value: BigInt, bits: Int) throws {
        try ABIType.int(bits: bits).validate()
        let limit = BigUInt(1) << (bits - 1)
        let fits = value.sign == .minus ? value.magnitude <= limit : value.magnitude < limit
        guard fits else { throw ABIError.integerOverflow }
    }
}
