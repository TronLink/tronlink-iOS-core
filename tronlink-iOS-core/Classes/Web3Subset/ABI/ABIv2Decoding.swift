
import BigInt
import Foundation

/// Decoding functions
public struct ABIv2Decoder {
    // Bound allocations even when several offsets point at the same payload, or
    // arrays contain zero-sized tuples whose count is not bounded by input bytes.
    private struct Budget {
        var nodes = 1_000_000
        var typeNodes = 1_000_000
        var payloadBytes = 64 * 1024 * 1024
    }

    /// Decodes Solidity parameters while preserving array and tuple nesting.
    public static func decode(types: [ABIv2.Element.InOut], data: Data) -> [AnyObject]? {
        return decode(types: types.map { $0.type }, data: data)
    }

    /// Decodes Solidity parameters while preserving array and tuple nesting.
    public static func decode(types: [ABIv2.Element.ParameterType], data: Data) -> [AnyObject]? {
        return decode(types: types, data: data, allowLegacyBytes32: true)
    }

    /// Set allowLegacyBytes32 to false for general ABI decoding. The legacy
    /// two-argument API retains token name/symbol compatibility: a single
    /// right-padded bytes32 string. Left-padded offset words are rejected.
    /// Inputs, custom errors and events disable it.
    public static func decode(types: [ABIv2.Element.ParameterType], data: Data, allowLegacyBytes32: Bool) -> [AnyObject]? {
        if allowLegacyBytes32, types.count == 1, data.count == 32,
           let value = decodeLegacyMetadata(type: types[0], data: data) {
            return [value]
        }
        var budget = Budget()
        return decodeTuple(types: types, data: data, base: 0, depth: 0, budget: &budget)
    }

    public static func decode(types: [ABIv2.Element.InOut], data: Data, allowLegacyBytes32: Bool) -> [AnyObject]? {
        return decode(types: types.map { $0.type }, data: data, allowLegacyBytes32: allowLegacyBytes32)
    }

    /// Decodes one parameter. bytesConsumed is its size in the containing
    /// head, not the absolute position of the next parameter or its tail size.
    /// Pass minimumTail as the enclosing head width when decoding a field
    /// inside a multi-argument payload. The original spelling is retained.
    public static func decodeSignleType(type: ABIv2.Element.ParameterType, data: Data, pointer: UInt64 = 0) -> (value: AnyObject?, bytesConsumed: UInt64?) {
        return decodeSignleType(type: type, data: data, pointer: pointer, allowLegacyBytes32: true)
    }

    // Keep this overload so existing four-argument function references remain valid.
    public static func decodeSignleType(type: ABIv2.Element.ParameterType, data: Data, pointer: UInt64 = 0, allowLegacyBytes32: Bool) -> (value: AnyObject?, bytesConsumed: UInt64?) {
        return decodeSignleType(type: type, data: data, pointer: pointer, allowLegacyBytes32: allowLegacyBytes32, minimumTail: nil)
    }

    public static func decodeSignleType(type: ABIv2.Element.ParameterType, data: Data, pointer: UInt64 = 0, allowLegacyBytes32: Bool, minimumTail: UInt64?) -> (value: AnyObject?, bytesConsumed: UInt64?) {
        var budget = Budget()
        guard let layout = ABIv2Layout.layout(of: type, depth: 0, nodes: &budget.typeNodes),
              pointer <= UInt64(data.count),
              layout.headSize <= UInt64(data.count) - pointer else { return (nil, nil) }
        let head = Int(pointer)
        let headSize = Int(layout.headSize)
        let tailFloor: Int
        if let minimumTail {
            guard minimumTail >= pointer + layout.headSize,
                  minimumTail <= UInt64(data.count) else { return (nil, nil) }
            tailFloor = Int(minimumTail)
        } else {
            tailFloor = head + headSize
        }
        // Validate the complete enclosing head even for static values and
        // before accepting a single-word legacy metadata response.
        if allowLegacyBytes32, pointer == 0, data.count == 32,
           let value = decodeLegacyMetadata(type: type, data: data) {
            return (value, layout.headSize)
        }
        guard let value = decodeValue(type: type, data: data, containerBase: 0,
                                      head: head, minimumTail: tailFloor,
                                      depth: 0, budget: &budget) else { return (nil, nil) }
        return (value, layout.headSize)
    }

    private static func decodeTuple(types: [ABIv2.Element.ParameterType], data: Data, base: Int,
                                    depth: Int, budget: inout Budget) -> [AnyObject]? {
        guard depth <= ABIv2Layout.maxDepth, base >= 0, base <= data.count,
              types.count <= budget.nodes else { return nil }
        var headSize = 0
        for type in types {
            guard let layout = ABIv2Layout.layout(of: type, depth: depth, nodes: &budget.typeNodes),
                  layout.headSize <= UInt64(data.count - base - headSize) else { return nil }
            headSize += Int(layout.headSize)
        }
        var values = [AnyObject]()
        var head = base
        for type in types {
            guard let layout = ABIv2Layout.layout(of: type, depth: depth, nodes: &budget.typeNodes),
                  let value = decodeValue(type: type, data: data, containerBase: base,
                                          head: head, minimumTail: headSize,
                                          depth: depth, budget: &budget) else { return nil }
            values.append(value)
            head += Int(layout.headSize)
        }
        return values
    }

    private static func decodeArray(type: ABIv2.Element.ParameterType, count: UInt64,
                                    data: Data, base: Int, depth: Int,
                                    budget: inout Budget) -> [AnyObject]? {
        guard depth <= ABIv2Layout.maxDepth, base >= 0, base <= data.count,
              count <= UInt64(budget.nodes),
              let layout = ABIv2Layout.layout(of: type, depth: depth, nodes: &budget.typeNodes) else { return nil }
        let (totalHead, overflow) = layout.headSize.multipliedReportingOverflow(by: count)
        guard !overflow, totalHead <= UInt64(data.count - base) else { return nil }
        // Count is bounded by the node budget before conversion or allocation.
        let length = Int(count)
        let headSize = Int(totalHead)
        var values = [AnyObject]()
        var head = base
        for _ in 0 ..< length {
            guard let value = decodeValue(type: type, data: data, containerBase: base,
                                          head: head, minimumTail: headSize,
                                          depth: depth, budget: &budget) else { return nil }
            values.append(value)
            head += Int(layout.headSize)
        }
        return values
    }

    private static func decodeValue(type: ABIv2.Element.ParameterType, data: Data,
                                    containerBase: Int, head: Int, minimumTail: Int,
                                    depth: Int, budget: inout Budget) -> AnyObject? {
        guard depth <= ABIv2Layout.maxDepth, budget.nodes > 0,
              containerBase >= 0, containerBase <= head, head <= data.count,
              let layout = ABIv2Layout.layout(of: type, depth: depth, nodes: &budget.typeNodes),
              layout.headSize <= UInt64(data.count - head) else { return nil }
        budget.nodes -= 1

        let start: Int
        if layout.isStatic {
            start = head
        } else {
            guard let offset = boundedWord(data: data, offset: head, maximum: data.count - containerBase),
                  offset >= minimumTail, offset % 32 == 0 else { return nil }
            start = containerBase + offset
        }

        switch type {
        case let .uint(bits), let .ufixed(bits, _):
            guard let word = read(data: data, offset: start, count: 32) else { return nil }
            let value = BigUInt(word)
            guard value.bitWidth <= Int(bits) else { return nil }
            if case let .ufixed(_, decimals) = type {
                guard let exact = ABIv2.FixedPoint(scaledValue: BigInt(value), decimals: decimals) else { return nil }
                return exact as AnyObject
            }
            return value as AnyObject
        case let .int(bits), let .fixed(bits, _):
            guard let word = read(data: data, offset: start, count: 32),
                  let first = word.first else { return nil }
            let unsigned = BigInt(BigUInt(word))
            let value = (first & 0x80) == 0 ? unsigned : unsigned - (BigInt(1) << 256)
            let limit = BigInt(1) << Int(bits - 1)
            guard value >= -limit, value < limit else { return nil }
            if case let .fixed(_, decimals) = type {
                guard let exact = ABIv2.FixedPoint(scaledValue: value, decimals: decimals) else { return nil }
                return exact as AnyObject
            }
            return value as AnyObject
        case .address:
            guard let word = read(data: data, offset: start, count: 32),
                  word.prefix(12).allSatisfy({ $0 == 0 }) else { return nil }
            return Web3Address(Data(word.suffix(20))) as AnyObject
        case .bool:
            guard let word = read(data: data, offset: start, count: 32) else { return nil }
            let value = BigUInt(word)
            guard value == 0 || value == 1 else { return nil }
            return (value == 1) as AnyObject
        case let .bytes(length):
            guard let word = read(data: data, offset: start, count: 32),
                  word.dropFirst(Int(length)).allSatisfy({ $0 == 0 }) else { return nil }
            return Data(word.prefix(Int(length))) as AnyObject
        case .function:
            guard let word = read(data: data, offset: start, count: 32),
                  word.dropFirst(24).allSatisfy({ $0 == 0 }) else { return nil }
            // A function value is address (20 bytes) + selector (4 bytes), then padding.
            return Data(word.prefix(24)) as AnyObject
        case .string, .dynamicBytes:
            guard start <= data.count, data.count - start >= 32,
                  let length = boundedWord(data: data, offset: start, maximum: data.count - start - 32) else { return nil }
            let padding = (32 - length % 32) % 32
            guard padding <= data.count - start - 32 - length,
                  length <= budget.payloadBytes else { return nil }
            if padding > 0 {
                guard let pad = read(data: data, offset: start + 32 + length, count: padding),
                      pad.allSatisfy({ $0 == 0 }) else { return nil }
            }
            budget.payloadBytes -= length
            guard let bytes = read(data: data, offset: start + 32, count: length) else { return nil }
            if case .string = type {
                guard let string = String(data: bytes, encoding: .utf8) else { return nil }
                return string as AnyObject
            }
            return bytes as AnyObject
        case let .array(subtype, length), let .fixedArray(subtype, length):
            if case .array(_, 0) = type {
                guard start <= data.count, data.count - start >= 32,
                      let count = boundedWord(data: data, offset: start, maximum: budget.nodes) else { return nil }
                // Array element offsets are relative to the tuple AFTER its length word.
                guard let values = decodeArray(type: subtype, count: UInt64(count), data: data,
                                               base: start + 32, depth: depth + 1, budget: &budget) else { return nil }
                return values as AnyObject
            }
            guard let values = decodeArray(type: subtype, count: length, data: data,
                                           base: start, depth: depth + 1, budget: &budget) else { return nil }
            return values as AnyObject
        case let .tuple(types: types):
            guard let values = decodeTuple(types: types, data: data, base: start,
                                           depth: depth + 1, budget: &budget) else { return nil }
            return values as AnyObject
        }
    }

    /// Offsets are relative to this Data value, including when it is a slice
    /// whose startIndex is not zero. Validate bounds before creating indices.
    private static func read(data: Data, offset: Int, count: Int) -> Data? {
        guard offset >= 0, count >= 0, offset <= data.count, count <= data.count - offset else { return nil }
        let lower = data.index(data.startIndex, offsetBy: offset)
        let upper = data.index(lower, offsetBy: count)
        return Data(data[lower ..< upper])
    }

    private static func boundedWord(data: Data, offset: Int, maximum: Int) -> Int? {
        guard maximum >= 0, let word = read(data: data, offset: offset, count: 32) else { return nil }
        let value = BigUInt(word)
        guard value <= BigUInt(maximum) else { return nil }
        return Int(value)
    }

    /// Some token contracts declare string metadata but return a bytes32 word.
    /// Preserve the historical fallback only for a single, top-level 32-byte
    /// response. Nested values and event data must never reinterpret a bad offset.
    private static func decodeLegacyMetadata(type: ABIv2.Element.ParameterType, data: Data) -> AnyObject? {
        // Only token name/symbol strings have an established compatibility need.
        // A bytes parameter must always contain the normal ABI offset and length.
        guard case .string = type, data.count == 32, let first = data.first else { return nil }
        // Token metadata is right-padded ASCII. A truncated ABI offset is
        // left-padded and must not become a name (offset 32/64 look like 0x20).
        guard first != 0 || data.allSatisfy({ $0 == 0 }) else { return nil }
        var bytes = first == 0 ? Data() : Data(data)
        // bytes32 metadata pads text with NUL bytes. Only this compatibility
        // path trims them; a normal ABI string preserves its declared bytes.
        while bytes.last == 0 {
            bytes.removeLast()
        }
        guard let string = String(data: bytes, encoding: .utf8) else { return nil }
        return string as AnyObject
    }

    /// Decodes log topics and unindexed event parameters.
    public static func decodeLog(event: ABIv2.Element.Event, eventLog: EventLog) -> [String: Any]? {
        let indexedInputs = event.inputs.filter { $0.indexed }
        let signatureCount = event.anonymous ? 0 : 1
        let logs = eventLog.topics
        guard logs.count == indexedInputs.count + signatureCount,
              logs.allSatisfy({ $0.count == 32 }) else { return nil }
        var budget = Budget()
        guard event.inputs.count <= budget.nodes else { return nil }
        for input in event.inputs {
            guard ABIv2Layout.layout(of: input.type, depth: 0, nodes: &budget.typeNodes) != nil else { return nil }
        }
        if !event.anonymous {
            guard logs.first == event.topic else { return nil }
        }

        var indexedValues = [AnyObject]()
        for (index, input) in indexedInputs.enumerated() {
            guard budget.nodes > 0,
                  ABIv2Layout.layout(of: input.type, depth: 0, nodes: &budget.typeNodes) != nil else { return nil }
            let topic = logs[index + signatureCount]
            switch input.type {
            case .array, .fixedArray, .tuple, .string, .dynamicBytes:
                // Indexed complex values contain a hash, including static tuples/arrays.
                budget.nodes -= 1
                indexedValues.append(Data(topic) as AnyObject)
            default:
                guard let value = decodeValue(type: input.type, data: topic, containerBase: 0,
                                              head: 0, minimumTail: 32, depth: 0,
                                              budget: &budget) else { return nil }
                indexedValues.append(value)
            }
        }

        let nonIndexedTypes = event.inputs.filter { !$0.indexed }.map { $0.type }
        guard let nonIndexedValues = decodeTuple(types: nonIndexedTypes, data: eventLog.data,
                                                base: 0, depth: 0, budget: &budget) else { return nil }
        var content: [String: Any] = ["name": event.name]
        var indexedIndex = 0
        var nonIndexedIndex = 0
        for (index, input) in event.inputs.enumerated() {
            let value: AnyObject
            if input.indexed {
                value = indexedValues[indexedIndex]
                indexedIndex += 1
            } else {
                value = nonIndexedValues[nonIndexedIndex]
                nonIndexedIndex += 1
            }
            content[String(index)] = value
            if !input.name.isEmpty {
                content[input.name] = value
            }
        }
        return content
    }
}
