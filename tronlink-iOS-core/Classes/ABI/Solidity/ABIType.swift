
import Foundation

public indirect enum ABIType: Equatable, CustomStringConvertible {
    /// Unsigned integer with `0 < bits <= 256`, `bits % 8 == 0`
    case uint(bits: Int)

    /// Signed integer with `0 < bits <= 256`, `bits % 8 == 0`
    case int(bits: Int)

    /// Address, similar to `uint(bits: 160)`
    case address

    /// Boolean
    case bool

    /// Signed fixed-point decimal number of M bits, `8 <= M <= 256`, `M % 8 == 0`, and `0 < N <= 80`, which denotes the value `v` as `v / (10 ** N)`
    case fixed(Int, Int)

    /// Unsigned fixed-point decimal number of M bits, `8 <= M <= 256`, `M % 8 == 0`, and `0 < N <= 80`, which denotes the value `v` as `v / (10 ** N)`
    case ufixed(Int, Int)

    /// Binary type of `M` bytes, `0 < M <= 32`.
    case bytes(Int)

    /// An address (20 bytes) followed by a function selector (4 bytes). Encoded identical to `bytes(24)`.
    case function(Function)

    /// Fixed-length array of M elements, `M >= 0`, of the given type.
    case array(ABIType, Int)

    /// Dynamic-sized byte sequence
    case dynamicBytes

    /// Dynamic-sized string
    case string

    /// Variable-length array of elements of the given type
    case dynamicArray(ABIType)

    /// Tuple consisting of elements of the given types
    case tuple([ABIType])

    /// Reject invalid declarations before range checks, padding or array encoding.
    func validate() throws {
        switch self {
        case .uint(let bits), .int(let bits):
            guard (8...256).contains(bits), bits % 8 == 0 else { throw ABIError.invalidArgumentType }
        case .fixed(let bits, let scale), .ufixed(let bits, let scale):
            guard (8...256).contains(bits), bits % 8 == 0,
                  (1...80).contains(scale) else { throw ABIError.invalidArgumentType }
        case .bytes(let count):
            guard (1...32).contains(count) else { throw ABIError.invalidArgumentType }
        case .array(let type, let count):
            guard count >= 0 else { throw ABIError.invalidArgumentType }
            try type.validate()
        case .dynamicArray(let type):
            try type.validate()
        case .tuple(let types):
            for type in types { try type.validate() }
        case .function(let function):
            for type in function.parameters { try type.validate() }
        case .address, .bool, .dynamicBytes, .string:
            break
        }
    }

    /// Whether this type uses an offset in its enclosing tuple.
    var isDynamic: Bool {
        switch self {
        case .uint, .int, .address, .bool, .fixed, .ufixed, .bytes:
            return false
        case .dynamicBytes, .string, .dynamicArray:
            return true
        case .array(let type, _):
            return type.isDynamic
        case .tuple(let types):
            return types.contains(where: { $0.isDynamic })
        case .function(let function):
            // ABIValue.function represents a full call, including its arguments.
            return function.parameters.contains(where: { $0.isDynamic })
        }
    }

    /// Type description
    ///
    /// This is the string as required for function selectors
    public var description: String {
        switch self {
        case .uint(let bits):
            return "uint\(bits)"
        case .int(let bits):
            return "int\(bits)"
        case .address:
            return "address"
        case .bool:
            return "bool"
        case .fixed(let m, let n):
            return "fixed\(m)x\(n)"
        case .ufixed(let m, let n):
            return "ufixed\(m)x\(n)"
        case .bytes(let size):
            return "bytes\(size)"
        case .function(let f):
            return f.description
        case .array(let type, let size):
            return "\(type)[\(size)]"
        case .dynamicBytes:
            return "bytes"
        case .string:
            return "string"
        case .dynamicArray(let type):
            return "\(type)[]"
        case .tuple(let types):
            var typeString = "("
            for type in types {
                typeString.append(type.description + ",")
            }
            typeString.removeLast()
            return typeString + ")"
        }
    }
}
