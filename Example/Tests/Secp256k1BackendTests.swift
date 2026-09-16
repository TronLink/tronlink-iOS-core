import XCTest
import BigInt
@testable import TLCore

final class Secp256k1BackendTests: XCTestCase {
    private struct DeterministicVector {
        let scalar: Int
        let privateKey: Data
        let hash: Data
    }

    private let privateKey = Data(repeating: 0, count: 31) + Data([1])
    private let messageHash = Data(repeating: 0x11, count: 32)
    private let signatureHex = "e7c93726a865578504442b1a6827f676e0ed74bdff2be3960d1e253bbcfc44626aa772b878bc912bdbb33a0014ec507c4b3896ea85aa914b74dee9b7ac3e56da01"

    private func deterministicVector(for scalar: Int) -> DeterministicVector {
        var privateKeyBytes = [UInt8](repeating: 0, count: 32)
        privateKeyBytes[28] = UInt8(truncatingIfNeeded: scalar >> 24)
        privateKeyBytes[29] = UInt8(truncatingIfNeeded: scalar >> 16)
        privateKeyBytes[30] = UInt8(truncatingIfNeeded: scalar >> 8)
        privateKeyBytes[31] = UInt8(truncatingIfNeeded: scalar)

        let hashBytes = (0..<32).map { index in
            UInt8(truncatingIfNeeded: scalar &* (index + 1) &+ index &* 37)
        }
        return DeterministicVector(
            scalar: scalar,
            privateKey: Data(privateKeyBytes),
            hash: Data(hashBytes)
        )
    }

    private func mismatchMessage(vector: DeterministicVector,
                                 expected: Data,
                                 actual: Data?,
                                 recoveryID: UInt8) -> String {
        return "scalar=\(vector.scalar); privateKey=\(vector.privateKey.hex); hash=\(vector.hash.hex); expected=\(expected.hex); actual=\(actual?.hex ?? "nil"); recoveryID=\(recoveryID)"
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

    func testRecoveryIDNormalizationRemainsByteCompatible() {
        let cases: [(UInt8, UInt8)] = [
            (0, 0), (1, 1), (2, 1), (3, 0),
            (27, 0), (28, 1), (29, 0), (30, 1)
        ]

        for item in cases {
            XCTAssertEqual(SECP256K1.normalizedRecoveryID(item.0), item.1)
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
        let compressed = try TLCore.Web3Utils.privateToPublic(privateKey, compressed: true)
        let uncompressed = try TLCore.Web3Utils.privateToPublic(privateKey, compressed: false)

        XCTAssertEqual(compressed.hex,
                       "0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798")
        XCTAssertEqual(try TLCore.Web3Utils.publicToAddressData(compressed),
                       try TLCore.Web3Utils.publicToAddressData(uncompressed))
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

    func testTrezorBackendIsSelfConsistentForOneThousandDeterministicVectors() throws {
        for scalar in 1...1000 {
            let vector = deterministicVector(for: scalar)
            let publicKey = try XCTUnwrap(TrezorSecp256k1Backend.privateToPublic(
                vector.privateKey,
                compressed: false
            ))
            let signature = try XCTUnwrap(TrezorSecp256k1Backend.sign(
                hash: vector.hash,
                privateKey: vector.privateKey
            ))
            let recoveryID = signature[64]
            let recoveredPublicKey = TrezorSecp256k1Backend.recover(
                hash: vector.hash,
                signature: Data(signature.prefix(64)),
                recoveryID: recoveryID,
                compressed: false
            )
            let facadeKey = TLCore.PrivateKey(vector.privateKey)
            let facadeSignature = try facadeKey.sign(hash: vector.hash).data
            let compressed = try XCTUnwrap(TrezorSecp256k1Backend.privateToPublic(
                vector.privateKey,
                compressed: true
            ))
            let expanded = TrezorSecp256k1Backend.uncompressPublicKey(compressed)
            let facadeCompressed = try TLCore.Web3Utils.privateToPublic(
                vector.privateKey,
                compressed: true
            )

            XCTAssertTrue(TrezorSecp256k1Backend.verifyPrivateKey(vector.privateKey))
            XCTAssertLessThanOrEqual(recoveryID, 1)
            XCTAssertEqual(
                facadeKey.publicKey,
                publicKey,
                mismatchMessage(
                    vector: vector,
                    expected: publicKey,
                    actual: facadeKey.publicKey,
                    recoveryID: recoveryID
                )
            )
            XCTAssertEqual(
                facadeSignature,
                signature,
                mismatchMessage(
                    vector: vector,
                    expected: signature,
                    actual: facadeSignature,
                    recoveryID: recoveryID
                )
            )
            XCTAssertEqual(
                recoveredPublicKey,
                publicKey,
                mismatchMessage(
                    vector: vector,
                    expected: publicKey,
                    actual: recoveredPublicKey,
                    recoveryID: recoveryID
                )
            )
            XCTAssertEqual(
                facadeCompressed,
                compressed,
                mismatchMessage(
                    vector: vector,
                    expected: compressed,
                    actual: facadeCompressed,
                    recoveryID: 0
                )
            )
            XCTAssertEqual(
                expanded,
                publicKey,
                mismatchMessage(
                    vector: vector,
                    expected: publicKey,
                    actual: expanded,
                    recoveryID: 0
                )
            )
        }
    }

    func testTrezorBackendRecoversRawZeroAndOneIDs() throws {
        let signature = try XCTUnwrap(Data.fromHex(signatureHex))
        let compactSignature = Data(signature.prefix(64))
        var recoveredPublicKeys = [Data]()

        for recoveryID: UInt8 in 0...1 {
            let publicKey = try XCTUnwrap(TrezorSecp256k1Backend.recover(
                hash: messageHash,
                signature: compactSignature,
                recoveryID: recoveryID,
                compressed: false
            ))
            recoveredPublicKeys.append(publicKey)

            XCTAssertEqual(
                try SECP256K1.recoverPublicKey(
                    hash: messageHash,
                    signature: compactSignature + Data([recoveryID]),
                    compressed: false
                ),
                publicKey,
                "privateKey=\(privateKey.hex); hash=\(messageHash.hex); expected=\(publicKey.hex); recoveryID=\(recoveryID)"
            )
        }

        XCTAssertNotEqual(recoveredPublicKeys[0], recoveredPublicKeys[1])
        XCTAssertEqual(recoveredPublicKeys[1],
                       TrezorSecp256k1Backend.privateToPublic(privateKey, compressed: false))
    }

    func testTrezorFacadeAndBackendRejectInvalidScalarsAndMalformedInputs() throws {
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

        let malformedPublicKey = Data([0x04]) + Data(repeating: 0, count: 32)
        XCTAssertThrowsError(try TLCore.Web3Utils.publicToAddressData(malformedPublicKey)) {
            guard case SECP256DataError.cannotParsePublicKey = $0 else {
                return XCTFail("Unexpected error: \($0)")
            }
        }
        XCTAssertNil(TrezorSecp256k1Backend.uncompressPublicKey(malformedPublicKey))
    }

    func testTrezorBackendSigningIsDeterministicAcrossOneHundredRuns() throws {
        let expectedSignature = try XCTUnwrap(Data.fromHex(signatureHex))

        for iteration in 0..<100 {
            let actualSignature = TrezorSecp256k1Backend.sign(
                hash: messageHash,
                privateKey: privateKey
            )
            let actualRecoveryID: String
            if let recoveryID = actualSignature?.last {
                actualRecoveryID = String(recoveryID)
            } else {
                actualRecoveryID = "absent"
            }

            XCTAssertEqual(
                actualSignature,
                expectedSignature,
                "iteration=\(iteration); privateKey=\(privateKey.hex); hash=\(messageHash.hex); old=\(expectedSignature.hex); new=\(actualSignature?.hex ?? "nil"); recoveryID=\(actualRecoveryID)"
            )
        }
    }

    func testTrezorBackendHasNoSharedMutableStateAcrossEightWorkers() throws {
        let vectors = try (1...8).map { scalar -> (DeterministicVector, Data, Data) in
            let vector = deterministicVector(for: scalar)
            let publicKey = try XCTUnwrap(TrezorSecp256k1Backend.privateToPublic(
                vector.privateKey,
                compressed: false
            ))
            let signature = try XCTUnwrap(TrezorSecp256k1Backend.sign(
                hash: vector.hash,
                privateKey: vector.privateKey
            ))
            return (vector, publicKey, signature)
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
                        expected: expected.2,
                        actual: signature,
                        recoveryID: signature?.last ?? 0xff
                    )
                } else if publicKey != expected.1 {
                    failure = mismatchMessage(
                        vector: expected.0,
                        expected: expected.1,
                        actual: publicKey,
                        recoveryID: signature?.last ?? 0xff
                    )
                } else if recovered != expected.1 {
                    failure = mismatchMessage(
                        vector: expected.0,
                        expected: expected.1,
                        actual: recovered,
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


final class Secp256k1RecoverySafetyTests: XCTestCase {
    private let generatorX = "79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798"
    private let one = Data(repeating: 0, count: 31) + Data([1])

    func testCancellingSignatureIsRejectedBeforeWritingAPublicKey() throws {
        // R = G and s = digest, so s*R - digest*G is infinity.
        // Both scalars are nonzero and in range; this exercises CORE-102,
        // rather than the existing length or zero-scalar rejection.
        let r = try XCTUnwrap(Data.fromHex(generatorX))
        for hash in [one, Data(repeating: 0x11, count: 32)] {
            let signatureBytes = Array(r + hash)
            let hashBytes = Array(hash)
            var curve = secp256k1
            var output = [UInt8](repeating: 0xa5, count: 65)
            let result = output.withUnsafeMutableBufferPointer { publicKey in
                signatureBytes.withUnsafeBufferPointer { signature in
                    hashBytes.withUnsafeBufferPointer { digest in
                        ecdsa_recover_pub_from_sig(&curve, publicKey.baseAddress!,
                                                   signature.baseAddress!, digest.baseAddress!, 0)
                    }
                }
            }
            XCTAssertEqual(result, 1)
            XCTAssertEqual(output, [UInt8](repeating: 0xa5, count: 65))
        }
    }

    func testCancellingSignatureReturnsTheExistingPublicRecoveryError() throws {
        let r = try XCTUnwrap(Data.fromHex(generatorX))
        for hash in [one, Data(repeating: 0x11, count: 32)] {
            let compact = r + hash
            for compressed in [false, true] {
                XCTAssertTrue(EthereumCrypto.recoverPublicKey(
                    hash: hash, signature: compact, recoveryID: 0, compressed: compressed
                ).isEmpty)
            }
            for recoveryID: UInt8 in [0, 27] {
                let signature = compact + Data([recoveryID])
                XCTAssertThrowsError(try TLCore.Web3Utils.hashECRecover(hash: hash, signature: signature)) {
                    guard case SECP256DataError.cannotRecoverPublicKey = $0 else {
                        return XCTFail("Unexpected recovery error: \($0)")
                    }
                }
                XCTAssertThrowsError(try TLCore.Web3Utils.getAddressFromSignature(hash, signature: signature.hex)) {
                    guard case SECP256DataError.cannotRecoverPublicKey = $0 else {
                        return XCTFail("Unexpected recovery error: \($0)")
                    }
                }
            }
        }
    }

    func testValidRecoveryPreservesPublicKeysAddressesAndSignatureForms() throws {
        let r = try XCTUnwrap(Data.fromHex(generatorX))
        let uncompressed = try XCTUnwrap(Data.fromHex("04" + generatorX
            + "483ada7726a3c4655da4fbfc0e1108a8fd17b448a68554199c47d08ffb10d4b8"))
        let compressed = Data([0x02]) + r
        // Public test key d=1 and nonce k=1: s = digest + r (mod n).
        // The equivalent high-S form uses n-s and the opposite recovery parity.
        let lowS = try XCTUnwrap(Data.fromHex("79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81799"))
        let highS = try XCTUnwrap(Data.fromHex("8641998106234453aa5f9d6a3178f4f7b812e00b817a776265dfdd31b93e29a8"))
        let vectors: [(hash: Data, s: Data, recoveryID: UInt8)] = [
            (one, lowS, 0), (one, highS, 1), (Data(repeating: 0, count: 32), r, 0)
        ]
        let expectedAddress = "0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf"
        for vector in vectors {
            let compact = r + vector.s
            XCTAssertEqual(EthereumCrypto.recoverPublicKey(
                hash: vector.hash, signature: compact, recoveryID: vector.recoveryID, compressed: false
            ), uncompressed)
            XCTAssertEqual(EthereumCrypto.recoverPublicKey(
                hash: vector.hash, signature: compact, recoveryID: vector.recoveryID, compressed: true
            ), compressed)
            for recoveryID in [vector.recoveryID, vector.recoveryID + 27] {
                let signature = compact + Data([recoveryID])
                let address = try TLCore.Web3Utils.hashECRecover(hash: vector.hash, signature: signature)
                XCTAssertEqual(address.address, expectedAddress)
                XCTAssertEqual(try TLCore.Web3Utils.getAddressFromSignature(vector.hash, signature: signature.hex), address)
                XCTAssertEqual("41" + address.addressData.hex, "417e5f4552091a69125d5dfcb7b8c2659029395bdf")
            }
        }
    }

    func testInverseOfZeroAndAModulusMultipleStaysZero() {
        for originalModulus in [secp256k1.prime, secp256k1.order] {
            var modulus = originalModulus
            for input in [bignum256(), originalModulus] {
                var value = input
                bn_inverse(&value, &modulus)
                XCTAssertNotEqual(bn_is_zero(&value), 0)
            }
        }
    }

    func testNonzeroInverseStillMultipliesToOne() throws {
        let inputs = [one, Data(repeating: 0, count: 31) + Data([2]),
                      try XCTUnwrap(Data.fromHex(generatorX))]
        for originalModulus in [secp256k1.prime, secp256k1.order] {
            var modulus = originalModulus
            for input in inputs {
                var value = bignum256()
                Array(input).withUnsafeBufferPointer { bn_read_be($0.baseAddress!, &value) }
                var inverse = value
                bn_inverse(&inverse, &modulus)
                var product = value
                bn_multiply(&inverse, &product, &modulus)
                bn_mod(&product, &modulus)
                var expected = bignum256()
                bn_one(&expected)
                XCTAssertNotEqual(bn_is_equal(&product, &expected), 0)
            }
        }
    }
}


final class ECDSADigestVerificationTests: XCTestCase {
    // SEC 2 sections 2.4.1 and 2.4.2: https://www.secg.org/sec2-v2.pdf
    private let vectors: [(curve: ecdsa_curve, x: String, y: String, order: String, prefix: UInt8)] = [
        (secp256k1,
         "79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798",
         "483ada7726a3c4655da4fbfc0e1108a8fd17b448a68554199c47d08ffb10d4b8",
         "fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141", 2),
        (nist256p1,
         "6b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296",
         "4fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f5",
         "ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632551", 3)
    ]
    private let zero = Data(repeating: 0, count: 32)
    private let one = Data(repeating: 0, count: 31) + Data([1])

    private func verify(curve: ecdsa_curve, publicKey: Data, signature: Data, digest: Data) -> Int32 {
        var parameters = curve
        return Array(publicKey).withUnsafeBufferPointer { key in
            Array(signature).withUnsafeBufferPointer { sig in
                Array(digest).withUnsafeBufferPointer { hash in
                    ecdsa_verify_digest(&parameters, key.baseAddress, sig.baseAddress, hash.baseAddress)
                }
            }
        }
    }

    func testAnalyticZeroModuloDigestSignaturesVerifyOnBothCurves() throws {
        for vector in vectors {
            let r = try XCTUnwrap(Data.fromHex(vector.x))
            let order = try XCTUnwrap(Data.fromHex(vector.order))
            let uncompressed = try XCTUnwrap(Data.fromHex("04" + vector.x + vector.y))
            // Synthetic fixture d=1, k=1, Q=G: for e=0 or e=n, s=r=G.x.
            // This signature is derived algebraically, independently of the library signer.
            let signature = r + r
            for digest in [zero, order] {
                for publicKey in [Data([vector.prefix]) + r, uncompressed] {
                    XCTAssertEqual(verify(curve: vector.curve, publicKey: publicKey,
                                          signature: signature, digest: digest), 0)
                }
            }
        }
    }

    func testInvalidScalarsAndFinalInfinityRemainRejected() throws {
        for vector in vectors {
            let r = try XCTUnwrap(Data.fromHex(vector.x))
            let order = try XCTUnwrap(Data.fromHex(vector.order))
            let publicKey = Data([vector.prefix]) + r
            for digest in [zero, order] {
                for invalid in [zero + r, r + zero, order + r, r + order] {
                    XCTAssertEqual(verify(curve: vector.curve, publicKey: publicKey,
                                          signature: invalid, digest: digest), 2)
                }
                let invalidPublicKey = Data([4]) + Data(repeating: 0, count: 64)
                XCTAssertEqual(verify(curve: vector.curve, publicKey: invalidPublicKey,
                                      signature: r + r, digest: digest), 1)
            }
            // e=n-r and Q=G make (e/s)*G + (r/s)*Q cancel to infinity.
            let negativeR = (BigUInt(order) - BigUInt(r)).serialize()
            let cancellingDigest = Data(repeating: 0, count: 32 - negativeR.count) + negativeR
            XCTAssertEqual(verify(curve: vector.curve, publicKey: publicKey,
                                  signature: r + r, digest: cancellingDigest), 5)
            // The valid zero-digest signature must not validate a different message.
            XCTAssertEqual(verify(curve: vector.curve, publicKey: publicKey,
                                  signature: r + r, digest: one), 5)
        }
    }

    func testPublicVerifierAndAddressRecoveryAgreeForZeroModuloDigests() throws {
        let vector = try XCTUnwrap(vectors.first)
        let r = try XCTUnwrap(Data.fromHex(vector.x))
        let order = try XCTUnwrap(Data.fromHex(vector.order))
        let uncompressed = try XCTUnwrap(Data.fromHex("04" + vector.x + vector.y))
        let expectedAddress = "0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf"
        for digest in [zero, order] {
            for publicKey in [Data([2]) + r, uncompressed] {
                for signature in [r + r, r + r + Data([0])] {
                    XCTAssertTrue(EthereumCrypto.verify(signature: signature, message: digest, publicKey: publicKey))
                    XCTAssertFalse(EthereumCrypto.verify(signature: signature, message: one, publicKey: publicKey))
                }
            }
            for recoveryID: UInt8 in [0, 27] {
                let signature = r + r + Data([recoveryID])
                // These are the same recovery APIs used by the app's verification paths.
                let address = try TLCore.Web3Utils.hashECRecover(hash: digest, signature: signature)
                XCTAssertEqual(address.address, expectedAddress)
                XCTAssertEqual(try TLCore.Web3Utils.getAddressFromSignature(digest, signature: signature.hex), address)
            }
        }
    }

    func testGeneratedBoundaryAndOrdinarySignaturesStillVerify() throws {
        let vector = try XCTUnwrap(vectors.first)
        let order = try XCTUnwrap(Data.fromHex(vector.order))
        let key = TLCore.PrivateKey(one)
        let ordinaryHash = Data(repeating: 0x11, count: 32)
        for digest in [zero, order, one, Data(repeating: 0xff, count: 32), ordinaryHash] {
            let signature = try key.sign(hash: digest).data
            XCTAssertEqual(signature.count, 65)
            XCTAssertTrue(EthereumCrypto.verify(signature: signature, message: digest, publicKey: key.publicKey))
            XCTAssertEqual(try TLCore.Web3Utils.hashECRecover(hash: digest, signature: signature), key.address)
            if digest == ordinaryHash {
                XCTAssertEqual(signature.hex,
                               "e7c93726a865578504442b1a6827f676e0ed74bdff2be3960d1e253bbcfc44626aa772b878bc912bdbb33a0014ec507c4b3896ea85aa914b74dee9b7ac3e56da01")
            }
        }
    }
}
