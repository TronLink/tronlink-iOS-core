import XCTest
@testable import TLCore

final class Secp256k1BackendTests: XCTestCase {
    private let privateKey = Data(repeating: 0, count: 31) + Data([1])
    private let messageHash = Data(repeating: 0x11, count: 32)
    private let signatureHex = "e7c93726a865578504442b1a6827f676e0ed74bdff2be3960d1e253bbcfc44626aa772b878bc912bdbb33a0014ec507c4b3896ea85aa914b74dee9b7ac3e56da01"

    func testCurrentBackendMatchesFixedSignatureVector() throws {
        let key = TLCore.PrivateKey(privateKey)
        let signature = try key.sign(hash: messageHash)

        XCTAssertEqual(signature.data.hex, signatureHex)
        XCTAssertEqual(signature.v, 1)
        XCTAssertEqual(key.publicKey.hex,
                       "0479be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798483ada7726a3c4655da4fbfc0e1108a8fd17b448a68554199c47d08ffb10d4b8")
        XCTAssertEqual(key.address.address, "0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf")
        XCTAssertEqual(try TLCore.Web3Utils.hashECRecover(hash: messageHash, signature: signature.data), key.address)
    }

    func testPublicValidationErrorsRemainStable() {
        XCTAssertThrowsError(try TLCore.PrivateKey(Data(repeating: 0, count: 31)).verify()) {
            guard case SECP256K1Error.invalidPrivateKeySize = $0 else {
                return XCTFail("Unexpected error: \($0)")
            }
        }
        XCTAssertThrowsError(try TLCore.PrivateKey(Data(repeating: 0, count: 32)).verify()) {
            guard case SECP256K1Error.invalidPrivateKey = $0 else {
                return XCTFail("Unexpected error: \($0)")
            }
        }
        XCTAssertThrowsError(try TLCore.PrivateKey(privateKey).sign(hash: Data(repeating: 0, count: 31))) {
            guard case SECP256K1Error.invalidHashSize = $0 else {
                return XCTFail("Unexpected error: \($0)")
            }
        }
    }

    func testPrivateKeyScalarBoundsRemainStable() throws {
        let nMinusOne = try XCTUnwrap(Data.fromHex("fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364140"))
        let n = try XCTUnwrap(Data.fromHex("fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141"))

        XCTAssertNoThrow(try TLCore.PrivateKey(nMinusOne).verify())
        XCTAssertThrowsError(try TLCore.PrivateKey(n).verify()) {
            guard case SECP256K1Error.invalidPrivateKey = $0 else {
                return XCTFail("Unexpected error: \($0)")
            }
        }
    }

    func testSignatureRecoveryIDBoundsRemainStable() throws {
        let compactSignature = Data(repeating: 0, count: 64)

        for recoveryID: UInt8 in 0 ... 3 {
            XCTAssertNoThrow(try TLCore.Signature(data: compactSignature + Data([recoveryID])).check())
        }
        XCTAssertThrowsError(try TLCore.Signature(data: compactSignature + Data([4])).check()) {
            guard case SECP256DataError.signatureCorrupted = $0 else {
                return XCTFail("Unexpected error: \($0)")
            }
        }
    }

    func testUnmarshalSignatureNormalizesLegacyRecoveryIDs() throws {
        let compactSignature = Data(repeating: 0, count: 64)

        for legacyRecoveryID: UInt8 in 27 ... 30 {
            let unmarshaled = try SECP256K1.unmarshalSignature(signatureData: compactSignature + Data([legacyRecoveryID]))
            XCTAssertEqual(unmarshaled.v, legacyRecoveryID - 27)
        }
    }

    func testMalformedSignatureSizesPreserveErrors() {
        for size in [64, 66] {
            XCTAssertThrowsError(try TLCore.Signature(data: Data(repeating: 0, count: size)).check()) {
                guard case SECP256K1Error.invalidSignatureSize = $0 else {
                    return XCTFail("Unexpected error: \($0)")
                }
            }
            XCTAssertThrowsError(try SECP256K1.unmarshalSignature(signatureData: Data(repeating: 0, count: size))) {
                guard case SECP256K1Error.invalidSignatureSize = $0 else {
                    return XCTFail("Unexpected error: \($0)")
                }
            }
        }
    }

    func testCompressedPublicKeyMatchesPrivateKeyOne() throws {
        XCTAssertEqual(try TLCore.Web3Utils.privateToPublic(privateKey, compressed: true).hex,
                       "0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798")
    }

    func testEthereumCryptoExposesTrezorPublicKeyForms() throws {
        let uncompressed = EthereumCrypto.getPublicKey(from: privateKey, compressed: false)
        let compressed = EthereumCrypto.getPublicKey(from: privateKey, compressed: true)

        XCTAssertEqual(uncompressed.hex,
                       "0479be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798483ada7726a3c4655da4fbfc0e1108a8fd17b448a68554199c47d08ffb10d4b8")
        XCTAssertEqual(compressed.hex,
                       "0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798")
        XCTAssertFalse(EthereumCrypto.uncompressPublicKey(compressed).isEmpty)
        XCTAssertEqual(EthereumCrypto.uncompressPublicKey(compressed), uncompressed)
    }

    func testEthereumCryptoRecoversRawTrezorPublicKey() throws {
        let signature = try XCTUnwrap(Data.fromHex(signatureHex))
        let recovered = EthereumCrypto.recoverPublicKey(
            hash: messageHash,
            signature: Data(signature.prefix(64)),
            recoveryID: signature[64],
            compressed: false
        )

        XCTAssertEqual(recovered, EthereumCrypto.getPublicKey(from: privateKey, compressed: false))
    }

    func testEthereumCryptoRejectsInvalidPrivateKeys() throws {
        let curveOrder = try XCTUnwrap(Data.fromHex("fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141"))
        let invalidPrivateKeys = [
            Data(repeating: 0, count: 31),
            Data(repeating: 0, count: 33),
            Data(repeating: 0, count: 32),
            curveOrder
        ]

        for invalidPrivateKey in invalidPrivateKeys {
            XCTAssertFalse(EthereumCrypto.isValidPrivateKey(invalidPrivateKey))
            XCTAssertTrue(EthereumCrypto.getPublicKey(from: invalidPrivateKey, compressed: false).isEmpty)
            XCTAssertTrue(EthereumCrypto.getPublicKey(from: invalidPrivateKey, compressed: true).isEmpty)
        }
        XCTAssertTrue(EthereumCrypto.isValidPrivateKey(privateKey))
    }

    func testEthereumCryptoRejectsInvalidCompressedPublicKeys() {
        let invalidLength = Data(repeating: 0, count: 32)
        let invalidPrefix = Data([0x04]) + Data(repeating: 0, count: 32)

        XCTAssertTrue(EthereumCrypto.uncompressPublicKey(invalidLength).isEmpty)
        XCTAssertTrue(EthereumCrypto.uncompressPublicKey(invalidPrefix).isEmpty)
    }

    func testEthereumCryptoRejectsInvalidRecoveryInputs() throws {
        let signature = try XCTUnwrap(Data.fromHex(signatureHex))
        let compactSignature = Data(signature.prefix(64))

        XCTAssertTrue(EthereumCrypto.recoverPublicKey(
            hash: Data(repeating: 0, count: 31),
            signature: compactSignature,
            recoveryID: signature[64],
            compressed: false
        ).isEmpty)
        for invalidLength in [63, 65] {
            XCTAssertTrue(EthereumCrypto.recoverPublicKey(
                hash: messageHash,
                signature: Data(repeating: 0, count: invalidLength),
                recoveryID: signature[64],
                compressed: false
            ).isEmpty)
        }
        XCTAssertTrue(EthereumCrypto.recoverPublicKey(
            hash: messageHash,
            signature: compactSignature,
            recoveryID: 4,
            compressed: false
        ).isEmpty)
        XCTAssertTrue(EthereumCrypto.recoverPublicKey(
            hash: messageHash,
            signature: Data(repeating: 0, count: 64),
            recoveryID: 0,
            compressed: false
        ).isEmpty)
    }
}
