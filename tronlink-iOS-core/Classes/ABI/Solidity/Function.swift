
import BigInt
import Foundation

public struct Function: Equatable, CustomStringConvertible {
    public var name: String
    public var parameters: [ABIType]

    public init(name: String, parameters: [ABIType]) {
        self.name = name
        self.parameters = parameters
    }

    /// Casts the arguments into the appropriate types for this function.
    ///
    /// - Throws:
    ///   - `ABIError.invalidArgumentType` if a value doesn't match the expected type.
    ///   - `ABIError.invalidNumberOfArguments` if the number of values doesn't match the number of parameters.
    public func castArguments(_ values: [Any]) throws -> [ABIValue] {
        if values.count != parameters.count {
            throw ABIError.invalidNumberOfArguments
        }
        return try zip(parameters, values).map { type, argument in
            let value = try ABIValue(argument, type: type)
            try value.validate(asArgument: true)
            return value
        }
    }

    /// Function signature
    public var description: String {
        var string = "\(name)("
        for param in parameters {
            string += param.description + ","
        }
        if string.hasSuffix(",") {
            string.removeLast()
        }
        string += ")"
        return string
    }
}
