import XCTest
@testable import TLCore

final class Secp256k1BackendTests: XCTestCase {
    private struct DifferentialVector {
        let scalar: Int
        let privateKey: Data
        let hash: Data
    }

    private let privateKey = Data(repeating: 0, count: 31) + Data([1])
    private let messageHash = Data(repeating: 0x11, count: 32)
    private let signatureHex = "e7c93726a865578504442b1a6827f676e0ed74bdff2be3960d1e253bbcfc44626aa772b878bc912bdbb33a0014ec507c4b3896ea85aa914b74dee9b7ac3e56da01"

    private func deterministicVector(for scalar: Int) -> DifferentialVector {
        var privateKeyBytes = [UInt8](repeating: 0, count: 32)
        privateKeyBytes[28] = UInt8(truncatingIfNeeded: scalar >> 24)
        privateKeyBytes[29] = UInt8(truncatingIfNeeded: scalar >> 16)
        privateKeyBytes[30] = UInt8(truncatingIfNeeded: scalar >> 8)
        privateKeyBytes[31] = UInt8(truncatingIfNeeded: scalar)

        let hashBytes = (0..<32).map { index in
            UInt8(truncatingIfNeeded: scalar &* (index + 1) &+ index &* 37)
        }
        return DifferentialVector(
            scalar: scalar,
            privateKey: Data(privateKeyBytes),
            hash: Data(hashBytes)
        )
    }

    private func mismatchMessage(vector: DifferentialVector,
                                 legacy: Data,
                                 trezor: Data?,
                                 recoveryID: UInt8) -> String {
        return "privateKey=\(vector.privateKey.hex); hash=\(vector.hash.hex); old=\(legacy.hex); new=\(trezor?.hex ?? "nil"); recoveryID=\(recoveryID)"
    }

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

    func testTrezorBackendMatchesLegacyForOneThousandDeterministicVectors() throws {
        for scalar in 1...1000 {
            let vector = deterministicVector(for: scalar)
            let legacyKey = TLCore.PrivateKey(vector.privateKey)
            let legacySignature = try legacyKey.sign(hash: vector.hash).data
            let trezorSignature = TrezorSecp256k1Backend.sign(
                hash: vector.hash,
                privateKey: vector.privateKey
            )
            let recoveryID = legacySignature[64]
            let trezorPublicKey = TrezorSecp256k1Backend.privateToPublic(
                vector.privateKey,
                compressed: false
            )
            let trezorRecoveredPublicKey = TrezorSecp256k1Backend.recover(
                hash: vector.hash,
                signature: Data(legacySignature.prefix(64)),
                recoveryID: recoveryID,
                compressed: false
            )

            XCTAssertTrue(TrezorSecp256k1Backend.verifyPrivateKey(vector.privateKey))
            XCTAssertEqual(
                trezorPublicKey,
                legacyKey.publicKey,
                mismatchMessage(
                    vector: vector,
                    legacy: legacyKey.publicKey,
                    trezor: trezorPublicKey,
                    recoveryID: recoveryID
                )
            )
            XCTAssertEqual(
                trezorSignature,
                legacySignature,
                mismatchMessage(
                    vector: vector,
                    legacy: legacySignature,
                    trezor: trezorSignature,
                    recoveryID: recoveryID
                )
            )
            XCTAssertEqual(
                trezorRecoveredPublicKey,
                legacyKey.publicKey,
                mismatchMessage(
                    vector: vector,
                    legacy: legacyKey.publicKey,
                    trezor: trezorRecoveredPublicKey,
                    recoveryID: recoveryID
                )
            )
        }
    }

    func testTrezorBackendMatchesOneThousandCompressedPublicKeys() throws {
        for scalar in 1...1000 {
            let vector = deterministicVector(for: scalar)
            let legacyCompressed = try TLCore.Web3Utils.privateToPublic(vector.privateKey, compressed: true)
            let legacyUncompressed = try TLCore.Web3Utils.privateToPublic(vector.privateKey, compressed: false)
            let trezorCompressed = TrezorSecp256k1Backend.privateToPublic(vector.privateKey, compressed: true)
            let trezorUncompressed = trezorCompressed.flatMap(TrezorSecp256k1Backend.uncompressPublicKey)

            XCTAssertEqual(
                trezorCompressed,
                legacyCompressed,
                mismatchMessage(
                    vector: vector,
                    legacy: legacyCompressed,
                    trezor: trezorCompressed,
                    recoveryID: 0
                )
            )
            XCTAssertEqual(
                trezorUncompressed,
                legacyUncompressed,
                mismatchMessage(
                    vector: vector,
                    legacy: legacyUncompressed,
                    trezor: trezorUncompressed,
                    recoveryID: 0
                )
            )
        }
    }

    func testTrezorBackendMatchesLegacyRecoveryForRawZeroAndOneIDs() throws {
        let signature = try XCTUnwrap(Data.fromHex(signatureHex))
        let compactSignature = Data(signature.prefix(64))

        for recoveryID: UInt8 in 0...1 {
            let legacySignature = compactSignature + Data([recoveryID])
            let legacyPublicKey = try SECP256K1.recoverPublicKey(
                hash: messageHash,
                signature: legacySignature,
                compressed: false
            )
            let trezorPublicKey = TrezorSecp256k1Backend.recover(
                hash: messageHash,
                signature: compactSignature,
                recoveryID: recoveryID,
                compressed: false
            )

            XCTAssertEqual(
                trezorPublicKey,
                legacyPublicKey,
                "privateKey=\(privateKey.hex); hash=\(messageHash.hex); old=\(legacyPublicKey.hex); new=\(trezorPublicKey?.hex ?? "nil"); recoveryID=\(recoveryID)"
            )
        }
    }

    func testTrezorBackendRejectsInvalidScalarsAndMalformedInputsLikeLegacy() throws {
        let curveOrder = try XCTUnwrap(Data.fromHex("fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141"))
        let invalidPrivateKeys = [
            Data(repeating: 0, count: 31),
            Data(repeating: 0, count: 33),
            Data(repeating: 0, count: 32),
            curveOrder
        ]

        for invalidPrivateKey in invalidPrivateKeys {
            XCTAssertThrowsError(try TLCore.PrivateKey(invalidPrivateKey).verify())
            XCTAssertFalse(TrezorSecp256k1Backend.verifyPrivateKey(invalidPrivateKey))
            XCTAssertThrowsError(try TLCore.Web3Utils.privateToPublic(invalidPrivateKey))
            XCTAssertNil(TrezorSecp256k1Backend.privateToPublic(invalidPrivateKey, compressed: false))
            XCTAssertThrowsError(try TLCore.PrivateKey(invalidPrivateKey).sign(hash: messageHash))
            XCTAssertNil(TrezorSecp256k1Backend.sign(hash: messageHash, privateKey: invalidPrivateKey))
        }

        for malformedHash in [Data(repeating: 0, count: 31), Data(repeating: 0, count: 33)] {
            XCTAssertThrowsError(try TLCore.PrivateKey(privateKey).sign(hash: malformedHash))
            XCTAssertNil(TrezorSecp256k1Backend.sign(hash: malformedHash, privateKey: privateKey))
            XCTAssertNil(TrezorSecp256k1Backend.recover(
                hash: malformedHash,
                signature: Data(repeating: 0, count: 64),
                recoveryID: 0,
                compressed: false
            ))
        }

        let signature = try XCTUnwrap(Data.fromHex(signatureHex))
        let compactSignature = Data(signature.prefix(64))
        for malformedSignature in [Data(repeating: 0, count: 63), Data(repeating: 0, count: 65)] {
            XCTAssertThrowsError(try SECP256K1.recoverPublicKey(
                hash: messageHash,
                signature: malformedSignature + Data([signature[64]])
            ))
            XCTAssertNil(TrezorSecp256k1Backend.recover(
                hash: messageHash,
                signature: malformedSignature,
                recoveryID: signature[64],
                compressed: false
            ))
        }

        XCTAssertThrowsError(try TLCore.Signature(data: compactSignature + Data([4])).check())
        XCTAssertNil(TrezorSecp256k1Backend.recover(
            hash: messageHash,
            signature: compactSignature,
            recoveryID: 4,
            compressed: false
        ))

        for malformedPublicKey in [
            Data(repeating: 0, count: 32),
            Data([0x04]) + Data(repeating: 0, count: 32)
        ] {
            XCTAssertThrowsError(try SECP256K1.parsePublicKey(serializedKey: malformedPublicKey))
            XCTAssertNil(TrezorSecp256k1Backend.uncompressPublicKey(malformedPublicKey))
        }
    }

    func testTrezorBackendSigningIsDeterministicAcrossOneHundredRuns() throws {
        let expectedSignature = try XCTUnwrap(Data.fromHex(signatureHex))

        for _ in 0..<100 {
            XCTAssertEqual(
                TrezorSecp256k1Backend.sign(hash: messageHash, privateKey: privateKey),
                expectedSignature
            )
        }
    }

    func testTrezorBackendHasNoSharedMutableStateAcrossEightWorkers() throws {
        let vectors = try (1...8).map { scalar -> (DifferentialVector, Data, Data) in
            let vector = deterministicVector(for: scalar)
            let legacyKey = TLCore.PrivateKey(vector.privateKey)
            return (vector, legacyKey.publicKey, try legacyKey.sign(hash: vector.hash).data)
        }
        let failureLock = NSLock()
        var firstFailure: String?

        DispatchQueue.concurrentPerform(iterations: 8) { worker in
            let expected = vectors[worker]
            for _ in 0..<100 {
                let privateKey = Data([UInt8](expected.0.privateKey))
                let hash = Data([UInt8](expected.0.hash))
                let signature = TrezorSecp256k1Backend.sign(hash: hash, privateKey: privateKey)
                let publicKey = TrezorSecp256k1Backend.privateToPublic(privateKey, compressed: false)
                let recovered = signature.flatMap {
                    TrezorSecp256k1Backend.recover(
                        hash: hash,
                        signature: Data($0.prefix(64)),
                        recoveryID: $0[64],
                        compressed: false
                    )
                }

                let failure: String?
                if signature != expected.2 {
                    failure = mismatchMessage(
                        vector: expected.0,
                        legacy: expected.2,
                        trezor: signature,
                        recoveryID: signature?.last ?? 0xff
                    )
                } else if publicKey != expected.1 {
                    failure = mismatchMessage(
                        vector: expected.0,
                        legacy: expected.1,
                        trezor: publicKey,
                        recoveryID: signature?.last ?? 0xff
                    )
                } else if recovered != expected.1 {
                    failure = mismatchMessage(
                        vector: expected.0,
                        legacy: expected.1,
                        trezor: recovered,
                        recoveryID: signature?.last ?? 0xff
                    )
                } else {
                    failure = nil
                }

                if let failure = failure {
                    failureLock.lock()
                    if firstFailure == nil {
                        firstFailure = failure
                    }
                    failureLock.unlock()
                    return
                }
            }
        }

        XCTAssertNil(firstFailure, firstFailure ?? "")
    }
}
