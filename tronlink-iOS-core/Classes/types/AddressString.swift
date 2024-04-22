import Foundation

public extension String {
    func isTRXAddress() -> Bool {
        if self.isEmpty {
            return false
        }
        
        let data = self.base58CheckData
        if data == nil {
            return false
        }
        
        var string = data?.toHexString()
        
        if string?.hasPrefix("0x") ?? false {
            string = string?.substring(from: 2)
        }
        
        if (string?.hasPrefix("41") ?? false) && (string?.count ?? 0) == 42 {
            return true
        }
        return false
    }

    func getRealAddress() -> String {
        if self.contains("(") {
            let list = self.split(separator: "(")
            let newList: [String] = list.compactMap { "\($0)" }
            return String(newList.last?.dropLast() ?? "")
        }
        return self
    }

    var base58CheckData: Data? {
        return Data(base58CheckDecoding: self)
    }
    
    func convertTronAddressToBase58HexAddress () -> String {
        return self.base58CheckData?.toHexString() ?? ""
    }
    
    func convertBase58HexAddressToTronAddress() -> String {
        return String.init(base58CheckEncoding: self.hexStringToUTF8Data() ?? Data())
    }
        
    func hexStringToUTF8Data() -> Data? {
        var data = Data(capacity: self.count / 2)
        
        let regex = try! NSRegularExpression(pattern: "[0-9a-f]{1,2}", options: .caseInsensitive)
        regex.enumerateMatches(in: self, range: NSMakeRange(0, utf16.count)) { match, flags, stop in
            let byteString = (self as NSString).substring(with: match!.range)
            var num = UInt8(byteString, radix: 16)!
            data.append(&num, count: 1)
        }
        
        guard data.count > 0 else { return nil }
        
        return data
    }
    
    func isEIP712TronAddress() -> Bool {
        if self.hasPrefix("T") || self.hasPrefix("41") {
            return true
        }
        return false
    }
    
    func convertEIP712TronAddress() -> String {
        var currentAddress = self
        if isEIP712TronAddress() {
            if currentAddress.hasPrefix("T") {
                currentAddress = currentAddress.base58CheckData?.toHexString() ?? ""
            }
            currentAddress = String(currentAddress.dropFirst("41".count))
        }else if currentAddress.hasPrefix("0x") {
            currentAddress = String(currentAddress.dropFirst("0x".count))
        }
        return currentAddress
    }

    var trimmed: String {
        return self.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }

}
