
import Foundation
import BigInt

//Sign
public extension String {
    private static let hexOnlyRegex = try! NSRegularExpression(pattern: "^[A-Fa-f0-9]+$")
    private static let hex0xRegex   = try! NSRegularExpression(pattern: "^0x[0-9A-Fa-f]*$")

    var length: Int {
        return utf16.count
    }
    
    var drop0x: String {
        if self.count > 2 && self.substring(with: 0..<2) == "0x" {
            return String(self.dropFirst(2))
        }
        return self
    }
    
    var add0x: String {
        return "0x" + self
    }
    
    func index(from: Int) -> Index {
        return self.index(startIndex, offsetBy: from)
    }
    
    func substring(from: Int) -> String {
        let fromIndex = index(from: from)
        return String(self[fromIndex...])
    }
    
    func substring(with r: Range<Int>) -> String {
        let startIndex = index(from: r.lowerBound)
        let endIndex = index(from: r.upperBound)
        return String(self[startIndex..<endIndex])
    }
    
    var hex: String {
        let data = self.data(using: .utf8) ?? Data()
        return data.map { String(format: "%02x", $0) }.joined()
    }

    var hexEncoded: String {
        let data = self.data(using: .utf8) ?? Data()
        return data.hexEncoded
    }
    
    var isHexEncoded: Bool {
        guard starts(with: "0x") else {
            return false
        }
        if String.hex0xRegex.matches(in: self, range: NSRange(self.startIndex..., in: self)).isEmpty {
            return false
        }
        return true
    }
    
    var signStringHexEncoded: String {
        if self.starts(with: "0x") {
            let judgeString = self.substring(from: 2)
            if String.hexOnlyRegex.matches(in: judgeString, range: NSMakeRange(0, judgeString.length)).isEmpty {
                return judgeString.hexEncoded.drop0x
            }
            return judgeString
        } else {
            if String.hexOnlyRegex.matches(in: self, range: NSMakeRange(0, self.length)).isEmpty {
                return self.hexEncoded.drop0x
            }
            return self
        }
    }
    
    var isSignStringHexEncoded: Bool {
        if self.starts(with: "0x") {
            let judgeString = self.substring(from: 2)
            if String.hexOnlyRegex.matches(in: judgeString, range: NSMakeRange(0, judgeString.length)).isEmpty {
                return false
            }
            return true
        } else {
            if String.hexOnlyRegex.matches(in: self, range: NSMakeRange(0, self.length)).isEmpty {
                return false
            }
            return true
        }
    }
}
