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
        // Strict: full hex, 21 bytes, 0x41 prefix. Never encode empty/partial Data.
        guard let data = hexDecodedData(),
              data.count == 21,
              data.first == 0x41 else {
            return ""
        }
        return String(base58CheckEncoding: data)
    }
        
    func hexDecodedData() -> Data? {
        let hex: String
        if hasPrefix("0x") || hasPrefix("0X") {
            hex = String(dropFirst(2))
        } else {
            hex = self
        }
        guard !hex.isEmpty, hex.count % 2 == 0 else { return nil }

        var data = Data(capacity: hex.count / 2)
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let num = UInt8(hex[index..<next], radix: 16) else { return nil }
            data.append(num)
            index = next
        }
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
