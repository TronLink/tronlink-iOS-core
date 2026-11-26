import Foundation

public extension String {
    func isTRXAddress() -> Bool {
        // TRON Base58Check addresses are exactly 34 ASCII bytes. Inspect only a
        // bounded prefix before the arbitrary-precision Base58 decoder sees input.
        guard utf8.prefix(35).count == 34 else { return false }
        
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
        // Strict: full hex, 21 bytes, 0x41 prefix. Never encode empty/partial Data.
        guard let data = hexDecodedData(),
              data.count == 21,
              data.first == 0x41 else {
            return ""
        }
        return String(base58CheckEncoding: data)
    }
        
    /// Decodes one or more ASCII hex byte pairs with an optional 0x or 0X prefix.
    func hexDecodedData() -> Data? {
        let hex = hasPrefix("0X") ? "0x" + dropFirst(2) : self
        guard let data = Data(hexString: hex), !data.isEmpty else { return nil }
        return data
    }
    
    func isEIP712TronAddress() -> Bool {
        if hasPrefix("T") {
            return isTRXAddress()
        }
        if hasPrefix("41") || hasPrefix("0x41") || hasPrefix("0X41") {
            guard let data = hexDecodedData(),
                  data.count == 21,
                  data.first == 0x41 else {
                return false
            }
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
            if currentAddress.hasPrefix("0x") || currentAddress.hasPrefix("0X") {
                currentAddress = String(currentAddress.dropFirst(2))
            }
            currentAddress = String(currentAddress.dropFirst("41".count))
        } else if currentAddress.hasPrefix("0x") {
            currentAddress = String(currentAddress.dropFirst("0x".count))
        }
        return currentAddress
    }

    var trimmed: String {
        return self.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }

}
