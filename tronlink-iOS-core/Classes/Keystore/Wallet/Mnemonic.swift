
import Foundation

public final class Mnemonic {
    /// Buffer size demanded by `mnemonic_from_data`, which returns NULL for anything smaller:
    /// `BIP39_MAX_WORDS * (BIP39_MAX_WORD_LENGTH + 1)`.
    private static let bufferLength = 240

    /// Maximum passphrase length in UTF-8 bytes, matching `BIP39_MAX_PASSPHRASE_LENGTH`.
    /// The C layer measures bytes with `strlen`, so this must never be compared against
    /// `String.count`, which counts characters: 65 four-byte emoji are 65 characters but 260 bytes.
    public static let maxPassphraseByteCount = 256

    /// Generates a menmoic string with the given strength in bits.
    ///
    /// - Parameter strength: strength in bits, a multiple of 32 between 128 and 256
    /// - Returns: mnemonic string
    /// - Throws: `Mnemonic.Error`
    public static func generate(strength: Int) throws -> String {
        guard strength % 32 == 0, strength >= 128, strength <= 256 else {
            throw Error.invalidStrength
        }
        var buffer = [CChar](repeating: 0, count: bufferLength)
        let mnemonic = buffer.withUnsafeMutableBufferPointer { buf -> String? in
            guard let result = mnemonic_generate(Int32(strength), buf.baseAddress, Int32(bufferLength)) else {
                return nil
            }
            return String(cString: result)
        }
        guard let mnemonic = mnemonic, !mnemonic.isEmpty else {
            throw Error.generationFailed
        }
        return mnemonic
    }

    /// Generates a mnemonic from seed data.
    ///
    /// - Parameter data: seed data for the mnemonic, a multiple of 4 bytes between 16 and 32
    /// - Returns: mnemonic string
    /// - Throws: `Mnemonic.Error`
    public static func generate(from data: Data) throws -> String {
        guard data.count % 4 == 0, data.count >= 16, data.count <= 32 else {
            throw Error.invalidStrength
        }
        var buffer = [CChar](repeating: 0, count: bufferLength)
        let mnemonic = buffer.withUnsafeMutableBufferPointer { buf -> String? in
            data.withUnsafeBytes { (dataPtr: UnsafeRawBufferPointer) -> String? in
                guard let baseAddress = dataPtr.baseAddress else {
                    return nil
                }
                let bytes = baseAddress.assumingMemoryBound(to: UInt8.self)
                guard let result = mnemonic_from_data(bytes, Int32(data.count), buf.baseAddress, Int32(bufferLength)) else {
                    return nil
                }
                return String(cString: result)
            }
        }
        guard let mnemonic = mnemonic, !mnemonic.isEmpty else {
            throw Error.generationFailed
        }
        return mnemonic
    }

    /// Determines if a mnemonic string is valid.
    ///
    /// - Parameter string: mnemonic string
    /// - Returns: `true` if the string is valid; `false` otherwise.
    public static func isValid(_ string: String) -> Bool {
        guard let asciiCString = string.cString(using: String.Encoding.ascii) else {
            return false
        }
        return mnemonic_check(asciiCString) != 0
    }

    /// Derives the wallet seed.
    ///
    /// - Parameters:
    ///   - mnemonic: mnemonic string
    ///   - passphrase: mnemonic passphrase
    /// - Returns: wallet seed
    /// - Throws: `Mnemonic.Error`
    public static func deriveSeed(mnemonic: String, passphrase: String) throws -> Data {
        guard passphrase.utf8.count <= maxPassphraseByteCount else {
            throw Error.passphraseTooLong
        }
        var seed = Data(repeating: 0, count: 512 / 8)
        let derived = seed.withUnsafeMutableBytes { seedPtr in
            mnemonic_to_seed(mnemonic, passphrase, seedPtr.bindMemory(to: UInt8.self).baseAddress, nil)
        }
        guard derived == 1 else {
            // The C layer zeroes the buffer on failure; returning it would derive every
            // wallet from an all-zero seed.
            seed.resetBytes(in: 0 ..< seed.count)
            throw Error.seedDerivationFailed
        }
        return seed
    }
}

extension Mnemonic {
    public enum Error: Swift.Error {
        case invalidStrength
        case generationFailed
        case passphraseTooLong
        case seedDerivationFailed
    }
}
