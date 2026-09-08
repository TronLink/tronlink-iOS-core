
import BigInt
import Foundation

extension ABIv2 {
    /// Function input parameter
    public struct Input: Decodable {
        var name: String?
        var type: String
        var indexed: Bool?
        var components: [Input]?
    }
    
    /// Function output parameter
    public struct Output: Decodable {
        var name: String?
        var type: String
        var components: [Output]?
    }
    
    /// Function
    public struct Record: Decodable {
        var name: String?
        var type: String?
        var payable: Bool?
        var constant: Bool?
        var stateMutability: String?
        var inputs: [ABIv2.Input]?
        var outputs: [ABIv2.Output]?
        var anonymous: Bool?
    }
    
    /// Abi Element
    public enum Element {
        /// Array size
        public enum ArraySize { // bytes for convenience
            /// Fixed size array or data
            case staticSize(UInt64)
            /// Dynamic size for dynamic arrays or data
            case dynamicSize
            /// Any other type
            case notArray
        }
        
        /// Function type
        case function(Function)
        /// Constructor
        case constructor(Constructor)
        /// Fallback
        case fallback(Fallback)
        /// Event
        case event(Event)
        /// Payable receive handler (no selector or arguments).
        case receive(Receive)
        /// Solidity custom error.
        case error(CustomError)
        
        /// Input or output type
        public struct InOut {
            let name: String
            let type: ParameterType
        }
        
        /// Function type
        public struct Function {
            let name: String?
            let inputs: [InOut]
            let outputs: [InOut]
            let constant: Bool
            let payable: Bool
        }
        
        /// Constructor type
        public struct Constructor {
            let inputs: [InOut]
            let constant: Bool
            let payable: Bool
        }
        
        /// Fallback type
        public struct Fallback {
            let constant: Bool
            let payable: Bool
        }
        
        public struct Receive {
            let payable: Bool
        }

        public struct CustomError {
            let name: String
            let inputs: [InOut]
        }

        /// Event type
        public struct Event {
            let name: String
            let inputs: [Input]
            let anonymous: Bool

            struct Input {
                let name: String
                let type: ParameterType
                let indexed: Bool
            }
        }
    }
}

extension ABIv2.Element {
    public func encodeParameters(_ parameters: [AnyObject]) -> Data? {
        switch self {
        case let .constructor(constructor):
            return ABIv2Encoder.encode(types: constructor.inputs, values: parameters)
        case let .function(function):
            guard let data = ABIv2Encoder.encode(types: function.inputs, values: parameters) else { return nil }
            return function.methodEncoding + data
        case let .error(error):
            guard let data = ABIv2Encoder.encode(types: error.inputs, values: parameters) else { return nil }
            return error.methodEncoding + data
        case .receive:
            return parameters.isEmpty ? Data() : nil
        case .event, .fallback:
            return nil
        }
    }

    public func decodeReturnData(_ data: Data) -> [String: Any]? {
        return decodeReturnData(data, allowLegacyBytes32: true)
    }

    /// General contract returns should disable the legacy token metadata path.
    public func decodeReturnData(_ data: Data, allowLegacyBytes32: Bool) -> [String: Any]? {
        switch self {
        case let .function(function):
            // A revert payload includes a four-byte selector and is not a
            // successful ABI return value. Empty data must not invent values.
            guard data.count % 32 == 0 else { return nil }
            return ABIv2.Element.decodeValues(function.outputs, data: data, allowLegacyBytes32: allowLegacyBytes32)
        case .error:
            return decodeInputData(data)
        case .constructor, .event, .fallback, .receive:
            return nil
        }
    }

    public func decodeInputData(_ rawData: Data) -> [String: Any]? {
        let data: Data
        let selector: Data?
        switch rawData.count % 32 {
        case 0:
            data = Data(rawData)
            selector = nil
        case 4:
            selector = Data(rawData.prefix(4))
            data = Data(rawData.dropFirst(4))
        default:
            return nil
        }
        switch self {
        case let .constructor(constructor):
            guard selector == nil else { return nil }
            return ABIv2.Element.decodeValues(constructor.inputs, data: data)
        case let .function(function):
            guard ABIv2.Element.validParameterTypes(function.inputs) else { return nil }
            guard selector == nil || selector == function.methodEncoding else { return nil }
            return ABIv2.Element.decodeValues(function.inputs, data: data)
        case let .error(error):
            guard ABIv2.Element.validParameterTypes(error.inputs) else { return nil }
            guard selector == nil || selector == error.methodEncoding else { return nil }
            return ABIv2.Element.decodeValues(error.inputs, data: data)
        case .receive:
            return rawData.isEmpty ? [:] : nil
        case .event, .fallback:
            return nil
        }
    }

    private static func validParameterTypes(_ parameters: [InOut]) -> Bool {
        var nodes = 1_000_000
        for parameter in parameters {
            guard ABIv2Layout.layout(of: parameter.type, depth: 0, nodes: &nodes) != nil else { return false }
        }
        return true
    }

    private static func decodeValues(_ parameters: [InOut], data: Data, allowLegacyBytes32: Bool = false) -> [String: Any]? {
        guard let values = ABIv2Decoder.decode(types: parameters.map { $0.type }, data: data,
                                              allowLegacyBytes32: allowLegacyBytes32),
              values.count == parameters.count else { return nil }
        var result = [String: Any]()
        for index in parameters.indices {
            result[String(index)] = values[index]
            if !parameters[index].name.isEmpty {
                result[parameters[index].name] = values[index]
            }
        }
        return result
    }
}

extension ABIv2.Element.Event {
    func decodeReturnedLogs(_ eventLog: EventLog) -> [String: Any]? {
        return ABIv2Decoder.decodeLog(event: self, eventLog: eventLog)
    }
}
