import Foundation

// MARK: - Internal extensions for Metrics module to decouple from main app
extension Date {
    func tronCore_getCurrentYMD_UTC() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone(secondsFromGMT: 0)
        return fmt.string(from: self)
    }
}

extension String {
    func tronCore_isPureNumber() -> Bool {
        let pattern = "^[-]?[0-9]+(\\.[0-9]+)?$"
        let predicate = NSPredicate(format: "SELF MATCHES %@", pattern)
        return predicate.evaluate(with: self)
    }
    
    func tronCore_removeFloatSuffixZero() -> String {
        var returnString = self
        if returnString.contains(".") {
            while returnString.hasSuffix("0") {
                returnString = String(returnString.dropLast())
            }
        }
        if returnString.hasSuffix(".") {
            returnString = String(returnString.dropLast())
        }
        while returnString.hasPrefix("0") {
            returnString.removeFirst()
        }
        if returnString.hasPrefix(".") {
            returnString = "0" + returnString
        }
        if returnString.isEmpty {
            returnString = "0"
        }
        return returnString
    }
    
    var tronCore_doubleValue: Double {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.decimalSeparator = "."
        if let result = formatter.number(from: self) {
            return result.doubleValue
        } else {
            formatter.decimalSeparator = ","
            if let result = formatter.number(from: self) {
                return result.doubleValue
            }
        }
        return 0
    }
    
    func tronCore_metricsDecimalNumber() -> NSDecimalNumber? {
        // Preserve the legacy meaning of an absent resource value, but do not turn
        // malformed/oversized values into zero. Bounds apply only to telemetry.
        if isEmpty { return .zero }
        guard utf8.prefix(258).count <= 257, tronCore_isPureNumber() else { return nil }
        let unsigned = hasPrefix("-") ? String(dropFirst()) : self
        let parts = unsigned.split(separator: ".", omittingEmptySubsequences: false)
        // These bounds exceed uint256 amounts and an Int-sized daily event count,
        // while staying within Decimal's exponent range (also used by asset reporting).
        guard let integerPart = parts.first, integerPart.count <= 127,
              parts.count == 1 || parts[1].count <= 128 else { return nil }
        let number = NSDecimalNumber(string: self, locale: Locale(identifier: "en_US_POSIX"))
        guard number != .notANumber else { return nil }
        return number
    }

    func tronCore_decimalNumberByAdding(numberString: String) -> NSDecimalNumber? {
        guard let left = tronCore_metricsDecimalNumber(),
              let right = numberString.tronCore_metricsDecimalNumber() else { return nil }
        var lhs = left.decimalValue
        var rhs = right.decimalValue
        var sum = Decimal()
        // Report arithmetic failures instead of raising an Objective-C exception.
        // Preserve default .plain rounding when Decimal loses precision.
        let error = NSDecimalAdd(&sum, &lhs, &rhs, .plain)
        guard error == .noError || error == .lossOfPrecision else { return nil }
        let result = NSDecimalNumber(decimal: sum)
        guard result != .notANumber,
              result.stringValue.tronCore_metricsDecimalNumber() != nil else { return nil }
        return result
    }
}
