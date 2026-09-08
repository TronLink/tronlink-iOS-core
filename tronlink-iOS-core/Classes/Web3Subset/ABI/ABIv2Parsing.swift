
import Foundation

extension ABIv2 {
    /// Parsing errors
    public enum ParsingError: Error {
        /// Cannot parse element type
        case elementTypeInvalid
        /// Cannot parse element name
        case elementNameInvalid
        /// Invalid function input
        case functionInputInvalid
        /// Invalid function output
        case functionOutputInvalid
        /// Invalid event input
        case eventInputInvalid
        /// Invalid parameter type
        case parameterTypeInvalid
        /// Parameter type not found
        case parameterTypeNotFound
        /// Invalid ABI
        case abiInvalid
        /// Printable / user displayable description
        public var localizedDescription: String {
            switch self {
            case .elementTypeInvalid:
                return "Cannot parse element type"
            case .elementNameInvalid:
                return "not parse element name"
            case .functionInputInvalid:
                return "Invalid function input"
            case .functionOutputInvalid:
                return "Invalid function output"
            case .eventInputInvalid:
                return "Invalid event input"
            case .parameterTypeInvalid:
                return "Invalid parameter type"
            case .parameterTypeNotFound:
                return "Parameter type not found"
            case .abiInvalid:
                return "Invalid ABI"
            }
        }
    }

    fileprivate enum ElementType: String {
        case function
        case constructor
        case fallback
        case event
        case receive
        case error
    }
}

extension ABIv2.Record {
    /// Parses record to ABIv2.Element
    public func parse() throws -> ABIv2.Element {
        let typeString = self.type != nil ? self.type! : "function"
        guard let type = ABIv2.ElementType(rawValue: typeString) else {
            throw ABIv2.ParsingError.elementTypeInvalid
        }
        if let stateMutability = stateMutability {
            switch stateMutability {
            case "pure", "view", "nonpayable", "payable":
                break
            default:
                throw ABIv2.ParsingError.abiInvalid
            }
            switch type {
            case .constructor, .fallback:
                guard stateMutability == "nonpayable" || stateMutability == "payable" else {
                    throw ABIv2.ParsingError.abiInvalid
                }
            default:
                break
            }
        }
        return try parseToElement(from: self, type: type)
    }
}

fileprivate func parseToElement(from abiRecord: ABIv2.Record, type: ABIv2.ElementType) throws -> ABIv2.Element {
    switch type {
    case .function:
        let function = try parseFunction(abiRecord: abiRecord)
        return ABIv2.Element.function(function)
    case .constructor:
        let constructor = try parseConstructor(abiRecord: abiRecord)
        return ABIv2.Element.constructor(constructor)
    case .fallback:
        let fallback = try parseFallback(abiRecord: abiRecord)
        return ABIv2.Element.fallback(fallback)
    case .event:
        let event = try parseEvent(abiRecord: abiRecord)
        return ABIv2.Element.event(event)
    case .receive:
        guard abiRecord.inputs?.isEmpty ?? true,
              abiRecord.outputs?.isEmpty ?? true,
              abiRecord.stateMutability.map({ $0 == "payable" }) ?? (abiRecord.payable == true) else {
            throw ABIv2.ParsingError.abiInvalid
        }
        return .receive(ABIv2.Element.Receive(payable: true))
    case .error:
        guard let name = abiRecord.name, !name.isEmpty else { throw ABIv2.ParsingError.elementNameInvalid }
        let inputs = try abiRecord.inputs?.map { try $0.parse() } ?? []
        return .error(ABIv2.Element.CustomError(name: name, inputs: inputs))
    }
}

fileprivate func parseFunction(abiRecord: ABIv2.Record) throws -> ABIv2.Element.Function {
    guard let name = abiRecord.name, !name.isEmpty else { throw ABIv2.ParsingError.elementNameInvalid }
    let inputs = try abiRecord.inputs?.map({ (input: ABIv2.Input) throws -> ABIv2.Element.InOut in
        let nativeInput = try input.parse()
        return nativeInput
    })
    let abiInputs = inputs != nil ? inputs! : [ABIv2.Element.InOut]()
    let outputs = try abiRecord.outputs?.map({ (output: ABIv2.Output) throws -> ABIv2.Element.InOut in
        let nativeOutput = try output.parse()
        return nativeOutput
    })
    let abiOutputs = outputs != nil ? outputs! : [ABIv2.Element.InOut]()
    let payable = abiRecord.stateMutability.map { $0 == "payable" } ?? (abiRecord.payable == true)
    let constant = abiRecord.stateMutability.map { $0 == "view" || $0 == "pure" } ?? (abiRecord.constant == true)
    let functionElement = ABIv2.Element.Function(name: name, inputs: abiInputs, outputs: abiOutputs, constant: constant, payable: payable)
    return functionElement
}

fileprivate func parseFallback(abiRecord: ABIv2.Record) throws -> ABIv2.Element.Fallback {
    let payable = abiRecord.stateMutability.map { $0 == "payable" } ?? (abiRecord.payable == true)
    let constant = abiRecord.stateMutability.map { $0 == "view" || $0 == "pure" } ?? (abiRecord.constant == true)
    let functionElement = ABIv2.Element.Fallback(constant: constant, payable: payable)
    return functionElement
}

fileprivate func parseConstructor(abiRecord: ABIv2.Record) throws -> ABIv2.Element.Constructor {
    let inputs = try abiRecord.inputs?.map({ (input: ABIv2.Input) throws -> ABIv2.Element.InOut in
        let nativeInput = try input.parse()
        return nativeInput
    })
    let abiInputs = inputs != nil ? inputs! : [ABIv2.Element.InOut]()
    let payable = abiRecord.stateMutability.map { $0 == "payable" } ?? (abiRecord.payable == true)
    let constant = false
    let functionElement = ABIv2.Element.Constructor(inputs: abiInputs, constant: constant, payable: payable)
    return functionElement
}

fileprivate func parseEvent(abiRecord: ABIv2.Record) throws -> ABIv2.Element.Event {
    guard let name = abiRecord.name, !name.isEmpty else { throw ABIv2.ParsingError.elementNameInvalid }
    let inputs = try abiRecord.inputs?.map({ (input: ABIv2.Input) throws -> ABIv2.Element.Event.Input in
        let nativeInput = try input.parseForEvent()
        return nativeInput
    })
    let abiInputs = inputs != nil ? inputs! : [ABIv2.Element.Event.Input]()
    let anonymous = abiRecord.anonymous != nil ? abiRecord.anonymous! : false
    let functionElement = ABIv2.Element.Event(name: name, inputs: abiInputs, anonymous: anonymous)
    return functionElement
}

extension ABIv2.Input {
    func parse() throws -> ABIv2.Element.InOut {
        return ABIv2.Element.InOut(name: name ?? "", type: try parameterType(depth: 0))
    }

    func parseForEvent() throws -> ABIv2.Element.Event.Input {
        return ABIv2.Element.Event.Input(name: name ?? "", type: try parameterType(depth: 0), indexed: indexed == true)
    }

    fileprivate func parameterType(depth: Int) throws -> ABIv2.Element.ParameterType {
        return try parseABIParameterType(type, depth: depth) { componentDepth in
            return try self.components?.map { try $0.parameterType(depth: componentDepth) }
        }
    }
}

extension ABIv2.Output {
    func parse() throws -> ABIv2.Element.InOut {
        return ABIv2.Element.InOut(name: name ?? "", type: try parameterType(depth: 0))
    }

    fileprivate func parameterType(depth: Int) throws -> ABIv2.Element.ParameterType {
        return try parseABIParameterType(type, depth: depth) { componentDepth in
            return try self.components?.map { try $0.parameterType(depth: componentDepth) }
        }
    }
}

fileprivate func parseABIParameterType(_ string: String, depth: Int, components: (Int) throws -> [ABIv2.Element.ParameterType]?) throws -> ABIv2.Element.ParameterType {
    guard depth < ABIv2Layout.maxDepth else { throw ABIv2.ParsingError.parameterTypeInvalid }
    let parsed = try ABIv2TypeParser.parseTypeString(string)
    let resolved: ABIv2.Element.ParameterType
    if string.hasPrefix("tuple") {
        resolved = try resolveTupleComponents(parsed, depth: depth, components: components)
    } else {
        resolved = parsed
    }
    guard ABIv2Layout.layout(of: resolved, depth: depth) != nil else { throw ABIv2.ParsingError.parameterTypeInvalid }
    return resolved
}

fileprivate func resolveTupleComponents(_ type: ABIv2.Element.ParameterType, depth: Int, components: (Int) throws -> [ABIv2.Element.ParameterType]?) throws -> ABIv2.Element.ParameterType {
    guard depth < ABIv2Layout.maxDepth else { throw ABIv2.ParsingError.parameterTypeInvalid }
    switch type {
    case let .array(subtype, length):
        return .array(type: try resolveTupleComponents(subtype, depth: depth + 1, components: components), length: length)
    case let .fixedArray(subtype, length):
        return .fixedArray(type: try resolveTupleComponents(subtype, depth: depth + 1, components: components), length: length)
    case .tuple:
        guard let types = try components(depth + 1) else { throw ABIv2.ParsingError.parameterTypeInvalid }
        return .tuple(types: types)
    default:
        throw ABIv2.ParsingError.parameterTypeInvalid
    }
}
