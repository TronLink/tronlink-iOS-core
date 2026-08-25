
import Foundation

public enum ABIError: LocalizedError {
    case integerOverflow
    case invalidUTF8String
    case invalidNumberOfArguments
    case invalidArgumentType

    public var errorDescription: String? {
        switch self {
        case .integerOverflow:
            return NSLocalizedString("Integer overflow", comment: "ABI encoder error")
        case .invalidUTF8String:
            return NSLocalizedString("Can't encode string as UTF8", comment: "ABI encoder error")
        case .invalidNumberOfArguments:
            return NSLocalizedString("Invalid number of arguments", comment: "ABI error description")
        case .invalidArgumentType:
            return NSLocalizedString("Invalid argument type", comment: "ABI error description")
        }
    }
}
