
import Foundation
extension ABIv2.Element {
    /// Specifies the type that parameters in a contract have.
    public enum ParameterType: ABIv2ElementPropertiesProtocol {
        /// uintN type
        case uint(bits: UInt64)
        /// intN type
        case int(bits: UInt64)
        /// Signed fixedMxN decimal, encoded as an integer scaled by 10^N.
        case fixed(bits: UInt64, decimals: UInt64)
        /// Unsigned fixedMxN decimal, encoded as an integer scaled by 10^N.
        case ufixed(bits: UInt64, decimals: UInt64)
        /// address type
        case address
        /// function type
        case function
        /// bool type
        case bool
        /// bytesN type
        case bytes(length: UInt64)
        /// array[N] or array[] type. Zero retains the legacy meaning of [].
        indirect case array(type: ParameterType, length: UInt64)
        /// Explicit fixed-size array, including [0], which differs from [].
        indirect case fixedArray(type: ParameterType, length: UInt64)
        /// bytes type
        case dynamicBytes
        /// string type
        case string
        /// tuple type
        indirect case tuple(types: [ParameterType])

        var isStatic: Bool {
            return ABIv2Layout.layout(of: self)?.isStatic ?? false
        }

        var isArray: Bool {
            switch self {
            case .array, .fixedArray:
                return true
            default:
                return false
            }
        }

        var isTuple: Bool {
            switch self {
            case .tuple:
                return true
            default:
                return false
            }
        }

        var subtype: ABIv2.Element.ParameterType? {
            switch self {
            case .array(type: let type, length: _), .fixedArray(type: let type, length: _):
                return type
            default:
                return nil
            }
        }

        var memoryUsage: UInt64 {
            return ABIv2Layout.layout(of: self)?.headSize ?? 0
        }

        var arraySize: ABIv2.Element.ArraySize {
            switch self {
            case .array(type: _, length: let length):
                if length == 0 {
                    return ArraySize.dynamicSize
                } else {
                    return ArraySize.staticSize(length)
                }
            case .fixedArray(type: _, length: let length):
                return ArraySize.staticSize(length)
            default:
                return ArraySize.notArray
            }
        }
    }
}

extension ABIv2.Element.ParameterType: Equatable {
    public static func == (lhs: ABIv2.Element.ParameterType, rhs: ABIv2.Element.ParameterType) -> Bool {
        switch (lhs, rhs) {
        case let (.uint(length1), .uint(length2)):
            return length1 == length2
        case let (.int(length1), .int(length2)):
            return length1 == length2
        case let (.fixed(bits1, decimals1), .fixed(bits2, decimals2)),
             let (.ufixed(bits1, decimals1), .ufixed(bits2, decimals2)):
            return bits1 == bits2 && decimals1 == decimals2
        case (.address, .address):
            return true
        case (.bool, .bool):
            return true
        case let (.bytes(length1), .bytes(length2)):
            return length1 == length2
        case (.function, .function):
            return true
        case let (.array(type1, length1), .array(type2, length2)):
            return type1 == type2 && length1 == length2
        case let (.fixedArray(type1, length1), .fixedArray(type2, length2)):
            return type1 == type2 && length1 == length2
        case let (.array(type1, length1), .fixedArray(type2, length2)),
             let (.fixedArray(type1, length1), .array(type2, length2)):
            return length1 > 0 && length1 == length2 && type1 == type2
        case let (.tuple(types1), .tuple(types2)):
            return types1 == types2
        case (.dynamicBytes, .dynamicBytes):
            return true
        case (.string, .string):
            return true
        default:
            return false
        }
    }
}

extension ABIv2.Element.Function {
    /// String representation of solidity function for hashing
    public var signature: String {
        return "\(name ?? "")(\(inputs.map { $0.type.abiRepresentation }.joined(separator: ",")))"
    }

    /// Function hash in hex
    public var methodString: String {
        return signature.keccak256().hex
    }
    
    /// Function hash
    public var methodEncoding: Data {
        return Data(signature.utf8).keccak256()[0..<4]
    }
}

extension ABIv2.Element.CustomError {
    public var signature: String {
        return "\(name)(\(inputs.map { $0.type.abiRepresentation }.joined(separator: ",")))"
    }

    /// Full Keccak-256 hash, matching Function.methodString.
    public var methodString: String {
        return signature.keccak256().hex
    }

    public var methodEncoding: Data {
        return Data(signature.utf8).keccak256()[0..<4]
    }
}

// MARK: - Event topic

extension ABIv2.Element.Event {
    /// String representation of solidity event for hashing
    public var signature: String {
        return "\(name)(\(inputs.map { $0.type.abiRepresentation }.joined(separator: ",")))"
    }
    
    /// Event hash
    public var topic: Data {
        return Data(signature.utf8).keccak256()
    }
}

extension ABIv2.Element.ParameterType: ABIv2Encoding {
    /// Solidity type representation
    public var abiRepresentation: String {
        switch self {
        case let .uint(bits):
            return "uint\(bits)"
        case let .int(bits):
            return "int\(bits)"
        case let .fixed(bits, decimals):
            return "fixed\(bits)x\(decimals)"
        case let .ufixed(bits, decimals):
            return "ufixed\(bits)x\(decimals)"
        case .address:
            return "address"
        case .bool:
            return "bool"
        case let .bytes(length):
            return "bytes\(length)"
        case .dynamicBytes:
            return "bytes"
        case .function:
            return "function"
        case let .array(type: type, length: length):
            if length == 0 {
                return "\(type.abiRepresentation)[]"
            }
            return "\(type.abiRepresentation)[\(length)]"
        case let .fixedArray(type: type, length: length):
            return "\(type.abiRepresentation)[\(length)]"
        case let .tuple(types: types):
            let typesRepresentation = types.map { $0.abiRepresentation }
            let typesJoined = typesRepresentation.joined(separator: ",")
            return "(\(typesJoined))"
        case .string:
            return "string"
        }
    }
}

extension ABIv2.Element.ParameterType: ABIv2Validation {
    /// Returns true if type is valid (or false for types like uint257)
    public var isValid: Bool {
        return ABIv2Layout.layout(of: self) != nil
    }
}
