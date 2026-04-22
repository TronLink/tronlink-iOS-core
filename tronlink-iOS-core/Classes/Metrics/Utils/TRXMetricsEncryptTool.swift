import CryptoSwift

final class TRXMetricsEncryptTool: NSObject {
    
    /// Encrypt action data using AES-CBC with key derived from password and timestamp
    static func encryptActionData(secretKey: String, ts: String, plaintext: String) -> String {
        do {
            let keyBase64 = try generateKey(secretKey: secretKey, ts: ts)
            let encrypted = try aesCBCEncrypt(plaintext: plaintext, keyBase64: keyBase64)
            return encrypted
        } catch {
            return ""
        }
    }
    
    /// Decrypt action data using AES-CBC with key derived from password and timestamp
    static func decryptActionData(secretKey: String, ts: String, encryptedText: String) -> String {
        do {
            let keyBase64 = try generateKey(secretKey: secretKey, ts: ts)
            let decryptedText = try aesCBCDecrypt(ciphertextBase64: encryptedText, keyBase64: keyBase64)
            return decryptedText
        } catch {
            return ""
        }
    }
    
    private static func generateKey(secretKey: String, ts: String) throws -> String {
        let val = ts + "123"
        let salt = Array(val.utf8)
        
        let pbkdf2 = try PKCS5.PBKDF2(
            password: Array(secretKey.utf8),
            salt: salt,
            iterations: 64,
            variant: .sha2(.sha256)
        )
        
        let keyBytes = try pbkdf2.calculate()
        return Data(keyBytes).base64EncodedString()
    }
    
    private static func aesCBCEncrypt(plaintext: String, keyBase64: String) throws -> String {
        guard let keyData = Data(base64Encoded: keyBase64), keyData.count == 32 else {
            throw NSError(domain: "AES", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid 256-bit key"])
        }
        
        let key = Array(keyData)
        let iv = AES.randomIV(16)
        let aes = try AES(
            key: key,
            blockMode: CBC(iv: iv),
            padding: .pkcs7
        )
        
        let plaintextBytes = Array(plaintext.utf8)
        let ciphertextBytes = try aes.encrypt(plaintextBytes)
        let encryptedData = Data(iv + ciphertextBytes)
        
        return encryptedData.base64EncodedString()
    }
    
    private static func aesCBCDecrypt(ciphertextBase64: String, keyBase64: String) throws -> String {
        guard let keyData = Data(base64Encoded: keyBase64), keyData.count == 32 else {
            throw NSError(domain: "AES", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid 256-bit key"])
        }
        let key = Array(keyData)
        
        guard let encryptedData = Data(base64Encoded: ciphertextBase64) else {
            throw NSError(domain: "AES", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid Base64 encrypted data"])
        }
        let encryptedBytes = Array(encryptedData)
        
        let cbcIvLength = 16
        guard encryptedBytes.count >= cbcIvLength else {
            throw NSError(domain: "AES", code: -3, userInfo: [NSLocalizedDescriptionKey: "Insufficient length of encrypted data"])
        }
        let iv = Array(encryptedBytes[0..<cbcIvLength])
        let ciphertextBytes = Array(encryptedBytes[cbcIvLength..<encryptedBytes.count])
        
        let aes = try AES(
            key: key,
            blockMode: CBC(iv: iv),
            padding: .pkcs7
        )
        
        let plaintextBytes = try aes.decrypt(ciphertextBytes)
        
        guard let plaintext = String(data: Data(plaintextBytes), encoding: .utf8) else {
            throw NSError(domain: "AES", code: -4, userInfo: [NSLocalizedDescriptionKey: "The decrypted result cannot be converted to a UTF-8 string"])
        }
        
        return plaintext
    }
}

