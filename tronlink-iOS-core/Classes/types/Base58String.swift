import Foundation
import BigInt

public enum Base58String {
    public static let btcAlphabet = [UInt8]("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz".utf8)
    public static let flickrAlphabet = [UInt8]("123456789abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ".utf8)
}

public extension String {
    
    init(base58Encoding bytes: Data, alphabet: [UInt8] = Base58String.btcAlphabet) {
        var x = BigUInt(bytes)
        let radix = BigUInt(alphabet.count)

        var answer = [UInt8]()
        answer.reserveCapacity(bytes.count)

        while x > 0 {
            let (quotient, modulus) = x.quotientAndRemainder(dividingBy: radix)
            answer.append(alphabet[Int(modulus)])
            x = quotient
        }

        let prefix = Array(bytes.prefix(while: {$0 == 0})).map { _ in alphabet[0] }
        answer.append(contentsOf: prefix)
        answer.reverse()

        self = String(bytes: answer, encoding: String.Encoding.utf8)!
    }
    
    init(base58CheckEncoding bytes: Data, alphabet: [UInt8] = Base58String.btcAlphabet) {
        let hash0 = bytes.sha256T()
        let hash1 = hash0.sha256T()
        var inputCheck = Data()
        inputCheck.append(bytes)
        inputCheck.append( hash1.subdata(in: 0..<4) )
        self = String.init(base58Encoding: inputCheck, alphabet: alphabet)
    }

}

public extension Data {

    init?(base58Decoding string: String, alphabet: [UInt8] = Base58String.btcAlphabet) {
        var answer = BigUInt(0)
        var j = BigUInt(1)
        let radix = BigUInt(alphabet.count)
        let byteString = [UInt8](string.utf8)

        for ch in byteString.reversed() {
            if let index = alphabet.index(of: ch) {
                answer = answer + (j * BigUInt(index))
                j *= radix
            } else {
                return nil
            }
        }

        let bytes = answer.serialize()
        self = byteString.prefix(while: { i in i == alphabet[0]}) + bytes
    }
    
    init?(base58CheckDecoding string: String, alphabet: [UInt8] = Base58String.btcAlphabet) {
        
        let data = Data(base58Decoding: string)
        guard let decodeCheck = data, decodeCheck.count >= 4 else {
            return nil
        }
        let decodeData = decodeCheck.subdata(in: 0..<(decodeCheck.count - 4))
        let hash0 = decodeData.sha256T()
        let hash1 = hash0.sha256T()
        if hash1[0] == decodeCheck[decodeData.count] && hash1[1] == decodeCheck[decodeData.count + 1] && hash1[2] == decodeCheck[decodeData.count + 2] && hash1[3] == decodeCheck[decodeData.count + 3] {
            self = decodeData
        } else {
            return nil
        }
    }

}

