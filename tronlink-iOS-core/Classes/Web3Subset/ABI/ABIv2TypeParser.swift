
import Foundation

/// Parses Solidity type names, canonical tuples and array suffixes.
public struct ABIv2TypeParser {
    public static func parseTypeString(_ string: String) throws -> ABIv2.Element.ParameterType {
        let (type, tail) = recursiveParseType(string)
        guard let parsed = type, tail == nil else {
            throw Web3Error.inputError("Failed to parse ABI element " + string)
        }
        return parsed
    }

    public static func recursiveParseType(_ string: String) -> (type: ABIv2.Element.ParameterType?, tail: String?) {
        var parser = Parser(bytes: Array(string.utf8))
        guard let type = parser.parseType(), parser.position == parser.bytes.count else { return (nil, nil) }
        return (type, nil)
    }

    public static func recursiveParseArray(baseType: ABIv2.Element.ParameterType, string: String) -> (type: ABIv2.Element.ParameterType?, tail: String?) {
        var parser = Parser(bytes: Array(string.utf8))
        guard parser.bytes.first == 91,
              let type = parser.parseArrays(baseType: baseType, depth: 0),
              parser.position == parser.bytes.count else { return (nil, nil) }
        return (type, nil)
    }

    private struct Parser {
        let bytes: [UInt8]
        var position = 0

        mutating func consume(_ byte: UInt8) -> Bool {
            guard position < bytes.count, bytes[position] == byte else { return false }
            position += 1
            return true
        }

        mutating func parseType(depth: Int = 0) -> ABIv2.Element.ParameterType? {
            guard depth < ABIv2Layout.maxDepth else { return nil }
            let baseType: ABIv2.Element.ParameterType
            if consume(40) { // (
                var components = [ABIv2.Element.ParameterType]()
                if !consume(41) {
                    while true {
                        guard let component = parseType(depth: depth + 1) else { return nil }
                        components.append(component)
                        if consume(41) { break }
                        guard consume(44) else { return nil }
                    }
                }
                baseType = .tuple(types: components)
            } else {
                let start = position
                while position < bytes.count, bytes[position] >= 97, bytes[position] <= 122 {
                    position += 1
                }
                guard let name = String(bytes: bytes[start..<position], encoding: .utf8) else { return nil }
                let numberStart = position
                while position < bytes.count, bytes[position] >= 48, bytes[position] <= 57 {
                    position += 1
                }
                var width: UInt64?
                if numberStart != position {
                    guard bytes[numberStart] != 48,
                          let digits = String(bytes: bytes[numberStart..<position], encoding: .utf8),
                          let parsed = UInt64(digits) else { return nil }
                    width = parsed
                }
                switch name {
                case "uint": baseType = .uint(bits: width ?? 256)
                case "int": baseType = .int(bits: width ?? 256)
                case "fixed", "ufixed":
                    let bits: UInt64
                    let decimals: UInt64
                    if let width = width {
                        guard consume(120) else { return nil } // x in fixedMxN
                        let decimalsStart = position
                        while position < bytes.count, bytes[position] >= 48, bytes[position] <= 57 {
                            position += 1
                        }
                        guard decimalsStart < position, bytes[decimalsStart] != 48,
                              let digits = String(bytes: bytes[decimalsStart..<position], encoding: .utf8),
                              let parsed = UInt64(digits) else { return nil }
                        bits = width
                        decimals = parsed
                    } else {
                        bits = 128
                        decimals = 18
                    }
                    baseType = name == "fixed" ? .fixed(bits: bits, decimals: decimals) : .ufixed(bits: bits, decimals: decimals)
                case "bytes":
                    if let width = width {
                        baseType = .bytes(length: width)
                    } else {
                        baseType = .dynamicBytes
                    }
                case "address" where width == nil: baseType = .address
                case "bool" where width == nil: baseType = .bool
                case "function" where width == nil: baseType = .function
                case "string" where width == nil: baseType = .string
                case "tuple" where width == nil && depth == 0:
                    // JSON ABI components are resolved by ABIv2.Input/Output.
                    baseType = .tuple(types: [])
                default: return nil
                }
            }
            return parseArrays(baseType: baseType, depth: depth)
        }

        mutating func parseArrays(baseType: ABIv2.Element.ParameterType, depth: Int) -> ABIv2.Element.ParameterType? {
            var type = baseType
            guard ABIv2Layout.layout(of: type, depth: depth) != nil else { return nil }
            while consume(91) { // [
                if consume(93) {
                    type = .array(type: type, length: 0)
                } else {
                    let start = position
                    while position < bytes.count, bytes[position] >= 48, bytes[position] <= 57 {
                        position += 1
                    }
                    guard start < position, position - start == 1 || bytes[start] != 48,
                          let digits = String(bytes: bytes[start..<position], encoding: .utf8),
                          let parsed = UInt64(digits), consume(93) else { return nil }
                    type = parsed == 0 ? .fixedArray(type: type, length: 0) : .array(type: type, length: parsed)
                }
                guard ABIv2Layout.layout(of: type, depth: depth) != nil else { return nil }
            }
            return type
        }
    }
}
