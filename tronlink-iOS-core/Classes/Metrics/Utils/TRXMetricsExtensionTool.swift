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
        let pattern = "^[0-9]+(\\.[0-9]+)?$"
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
    
    func tronCore_decimalNumberByAdding(numberString: String) -> NSDecimalNumber {
        var inputNumberString = numberString
        var currentString = self 
        if !self.tronCore_isPureNumber() || self == "" {
            currentString = "0"
        }
        if !numberString.tronCore_isPureNumber() || numberString == "" {
            inputNumberString = "0"
        }
        let currentDecimalNumber = NSDecimalNumber(string: currentString)
        let inputDecimalNumber = NSDecimalNumber(string: inputNumberString)
        return currentDecimalNumber.adding(inputDecimalNumber)
    }
}
