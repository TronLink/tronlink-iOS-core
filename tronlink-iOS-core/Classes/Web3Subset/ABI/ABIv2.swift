
import Foundation

/// Element type protocol
protocol ABIv2ElementPropertiesProtocol {
    /// Returns true if array is has fixed length
    var isStatic: Bool { get }
    /// Returns true if type is array
    var isArray: Bool { get }
    /// Returns true if type is tuple
    var isTuple: Bool { get }
    /// Returns array size if type
    var arraySize: ABIv2.Element.ArraySize { get }
    /// Returns subtype of array
    var subtype: ABIv2.Element.ParameterType? { get }
    /// Returns memory usage of type
    var memoryUsage: UInt64 { get }
}

protocol ABIv2Encoding {
    var abiRepresentation: String { get }
}

protocol ABIv2Validation {
    var isValid: Bool { get }
}

/// Parses smart contract json abi to work with smart contract's functions
public struct ABIv2 {}

/// Validates recursive ABI types and computes their size in the containing head.
enum ABIv2Layout {
    static let maxDepth = 64
    private static let maxNodes = 1_000_000

    static func layout(of type: ABIv2.Element.ParameterType, depth: Int = 0) -> (isStatic: Bool, headSize: UInt64)? {
        var nodes = maxNodes
        return layout(of: type, depth: depth, nodes: &nodes)
    }

    // A depth bound alone cannot bound traversal of a tuple tree whose arrays
    // share subtrees. Every visit consumes the same per-layout node budget.
    static func layout(of type: ABIv2.Element.ParameterType, depth: Int, nodes: inout Int) -> (isStatic: Bool, headSize: UInt64)? {
        guard depth >= 0, depth < maxDepth, nodes > 0 else { return nil }
        nodes -= 1
        switch type {
        case let .uint(bits), let .int(bits):
            guard bits > 0, bits <= 256, bits % 8 == 0 else { return nil }
            return (true, 32)
        case let .fixed(bits, decimals), let .ufixed(bits, decimals):
            guard bits >= 8, bits <= 256, bits % 8 == 0,
                  decimals >= 1, decimals <= 80 else { return nil }
            return (true, 32)
        case let .bytes(length):
            guard length > 0, length <= 32 else { return nil }
            return (true, 32)
        case .address, .function, .bool:
            return (true, 32)
        case .string, .dynamicBytes:
            return (false, 32)
        case let .array(subtype, length), let .fixedArray(subtype, length):
            guard let element = layout(of: subtype, depth: depth + 1, nodes: &nodes),
                  length <= UInt64(Int.max) else { return nil }
            // The legacy array case uses zero for []; fixedArray preserves [0].
            if case .array = type, length == 0 { return (false, 32) }
            let (size, overflow) = element.headSize.multipliedReportingOverflow(by: length)
            guard !overflow, size <= UInt64(Int.max) else { return nil }
            return (element.isStatic, element.isStatic ? size : 32)
        case let .tuple(types):
            var isStatic = true
            var size: UInt64 = 0
            for subtype in types {
                guard let element = layout(of: subtype, depth: depth + 1, nodes: &nodes) else { return nil }
                let (nextSize, overflow) = size.addingReportingOverflow(element.headSize)
                guard !overflow, nextSize <= UInt64(Int.max) else { return nil }
                size = nextSize
                isStatic = isStatic && element.isStatic
            }
            return (isStatic, isStatic ? size : 32)
        }
    }
}
