#import <XCTest/XCTest.h>
#import <TLCore/TLMnemonicWordlist.h>
@import TLCoreTrezorInternal;

@interface TrezorBoundaryTests : XCTestCase
@end

@implementation TrezorBoundaryTests

- (void)testPublicWordlistContract {
    const char * const *words = mnemonic_wordlist();
    XCTAssertTrue(words != NULL);
    if (!words) return;
    XCTAssertEqual(strcmp(words[0], "abandon"), 0);
    XCTAssertEqual(strcmp(words[2047], "zoo"), 0);
    XCTAssertTrue(words[2048] == NULL);
}

- (void)testPublicOnlyNodesKeepTheirAddressAndRejectPrivateOperations {
    uint8_t chain[32] = {0}, scalar[32] = {0};
    scalar[31] = 1;
    HDNode signer = {0}, watch = {0};
    XCTAssertEqual(hdnode_from_xprv(0, 0, chain, scalar, "secp256k1", &signer), 1);
    hdnode_fill_public_key(&signer);
    XCTAssertEqual(hdnode_from_xpub(0, 0, chain, signer.public_key, "secp256k1", &watch), 1);
    uint8_t fromPrivate[20], fromPublic[20];
    XCTAssertEqual(hdnode_get_ethereum_pubkeyhash(&signer, fromPrivate), 1);
    XCTAssertEqual(hdnode_get_ethereum_pubkeyhash(&watch, fromPublic), 1);
    XCTAssertEqual(memcmp(fromPrivate, fromPublic, 20), 0);
    XCTAssertEqual(hdnode_public_ckd(&watch, 7), 1);
    XCTAssertEqual(hdnode_private_ckd(&signer, 7), 1);
    hdnode_fill_public_key(&signer);
    XCTAssertEqual(memcmp(watch.public_key, signer.public_key, 33), 0);

    HDNode before;
    memcpy(&before, &watch, sizeof(before));
    uint32_t index = 1, fingerprint = 17;
    XCTAssertEqual(hdnode_private_ckd(&watch, index), 0);
    XCTAssertEqual(hdnode_private_ckd_cached(&watch, &index, 1, &fingerprint), 0);
    XCTAssertEqual(fingerprint, 17u);
    XCTAssertEqual(memcmp(&before, &watch, sizeof(watch)), 0);
    char xprv[112] = "previous";
    XCTAssertEqual(hdnode_serialize_private(&watch, 0, 0x0488ADE4, xprv, sizeof(xprv)), 0);
    XCTAssertEqual(xprv[0], 0);
    uint8_t sig[64], digest[32] = {0}, zeros[64] = {0};
    memset(sig, 0xa5, sizeof(sig));
    XCTAssertNotEqual(hdnode_sign_digest(&watch, digest, sig, NULL, NULL), 0);
    XCTAssertEqual(memcmp(sig, zeros, 64), 0);
}

- (void)testECDHChecksScalarAndReportsOutputLength {
    uint8_t chain[32] = {0}, scalar[32] = {0}, zero[65] = {0};
    scalar[31] = 1;
    HDNode node;
    XCTAssertEqual(hdnode_from_xprv(0, 0, chain, scalar, "secp256k1", &node), 1);
    hdnode_fill_public_key(&node);
    uint8_t result[65], expected[65];
    int size = 0;
    XCTAssertEqual(hdnode_get_shared_key(&node, node.public_key, result, &size), 0);
    XCTAssertEqual(size, 65);
    ecdsa_get_public_key65(node.curve->params, scalar, expected);
    XCTAssertEqual(memcmp(result, expected, sizeof(result)), 0);
    XCTAssertNotEqual(ecdh_multiply(node.curve->params, zero, node.public_key, result), 0);
    XCTAssertEqual(memcmp(result, zero, sizeof(result)), 0);
    bn_write_be(&node.curve->params->order, scalar);
    XCTAssertNotEqual(ecdh_multiply(node.curve->params, scalar, node.public_key, result), 0);
    memset(node.private_key, 0, sizeof(node.private_key));
    memset(result, 0xa5, sizeof(result));
    XCTAssertNotEqual(hdnode_get_shared_key(&node, node.public_key, result, &size), 0);
    XCTAssertEqual(size, 0);
    XCTAssertEqual(memcmp(result, zero, sizeof(result)), 0);
}

- (void)testEd25519RequiresMatchingPublicKeyIncludingForAZeroSeed {
    ed25519_secret_key seed = {0};
    ed25519_public_key pk;
    ed25519_signature sig, zeros = {0};
    const uint8_t msg[] = "wallet";
    ed25519_publickey(seed, pk);
    XCTAssertEqual(ed25519_sign_checked(msg, sizeof(msg)-1, seed, pk, sig), 0);
    XCTAssertEqual(ed25519_sign_open(msg, sizeof(msg)-1, pk, sig), 0);
    pk[0] ^= 1;
    XCTAssertNotEqual(ed25519_sign_checked(msg, sizeof(msg)-1, seed, pk, sig), 0);
    XCTAssertEqual(memcmp(sig, zeros, sizeof(sig)), 0);
    memset(sig, 0xa5, sizeof(sig));
    ed25519_sign(msg, sizeof(msg)-1, seed, pk, sig);
    XCTAssertEqual(memcmp(sig, zeros, sizeof(sig)), 0);
}

- (void)testCachedEd25519PublicKeyIsCheckedForEachHashVariant {
    const char *curves[] = {"ed25519", "ed25519-sha3", "ed25519-keccak"};
    uint8_t seed[32] = {0}, chain[32] = {0}, message[] = "wallet", zeros[64] = {0};
    for (size_t i = 0; i < sizeof(curves) / sizeof(curves[0]); i++) {
        HDNode node = {0};
        XCTAssertEqual(hdnode_from_xprv(0, 0, chain, seed, curves[i], &node), 1);
        uint8_t signature[64];
        XCTAssertEqual(hdnode_sign(&node, message, sizeof(message)-1, HASHER_SHA2, signature, NULL, NULL), 0);
        node.public_key[1] ^= 1;
        XCTAssertNotEqual(hdnode_sign(&node, message, sizeof(message)-1, HASHER_SHA2, signature, NULL, NULL), 0);
        XCTAssertEqual(memcmp(signature, zeros, sizeof(signature)), 0);
    }
}

- (void)testScalarExpansionChecksLengthBeforeWriting {
    uint8_t input[65] = {1}, encoded[32];
    bignum256modm scalar, previous;
    XCTAssertEqual(expand256_modm_checked(scalar, input, 64), 1);
    contract256_modm(encoded, scalar);
    XCTAssertEqual(memcmp(encoded, input, sizeof(encoded)), 0);
    memcpy(previous, scalar, sizeof(scalar));
    XCTAssertEqual(expand256_modm_checked(scalar, input, sizeof(input)), 0);
    XCTAssertEqual(memcmp(previous, scalar, sizeof(scalar)), 0);
    XCTAssertEqual(expand256_modm_checked(scalar, NULL, 0), 1);
    contract256_modm(encoded, scalar);
    XCTAssertEqual(memcmp(encoded, input + 1, sizeof(encoded)), 0);
}

- (void)testPBKDF2ChecksCapacityAndKeepsKnownOutputs {
    const uint8_t pass[] = "password", salt[] = "salt";
    const uint8_t sha256[] = {0x12,0x0f,0xb6,0xcf,0xfc,0xf8,0xb3,0x2c};
    const uint8_t sha512[] = {0x86,0x7f,0x70,0xcf,0x1a,0xde,0x02,0xcf};
    uint8_t out[8];
    XCTAssertEqual(pbkdf2_hmac_sha256_checked(pass, 8, salt, 4, 1, out, 8, sizeof(out)), 1);
    XCTAssertEqual(memcmp(out, sha256, sizeof(out)), 0);
    XCTAssertEqual(pbkdf2_hmac_sha512_checked(pass, 8, salt, 4, 1, out, 9, sizeof(out)), 0);
    XCTAssertEqual(pbkdf2_hmac_sha256_checked(pass, 8, salt, 4, 1, out, -1, sizeof(out)), 0);
    XCTAssertEqual(pbkdf2_hmac_sha512_checked(pass, 8, salt, -1, 1, out, 8, sizeof(out)), 0);
    XCTAssertEqual(pbkdf2_hmac_sha256_checked(pass, -1, salt, 4, 1, out, 8, sizeof(out)), 0);
    XCTAssertEqual(pbkdf2_hmac_sha256_checked(pass, 8, salt, 4, 0, out, 8, sizeof(out)), 0);
    XCTAssertEqual(memcmp(out, sha256, sizeof(out)), 0);
    XCTAssertEqual(pbkdf2_hmac_sha512_checked(pass, 8, salt, 4, 1, out, 8, sizeof(out)), 1);
    XCTAssertEqual(memcmp(out, sha512, sizeof(out)), 0);
}

- (void)testChaChaSplitsLargeInputsOnlyAtBlockBoundaries {
    XCTAssertEqual(chacha20poly1305_chunk_size(0), 0u);
    XCTAssertEqual(chacha20poly1305_chunk_size(65), 65u);
    XCTAssertEqual(chacha20poly1305_chunk_size(UINT32_MAX), UINT32_MAX);
#if SIZE_MAX > UINT32_MAX
    const size_t length = (size_t)UINT32_MAX + 1;
    uint32_t first = chacha20poly1305_chunk_size(length);
    XCTAssertEqual(first % 64, 0u);
    XCTAssertEqual(first, UINT32_MAX - 63u);
    XCTAssertEqual(chacha20poly1305_chunk_size(length - first), 64u);
#endif
}

- (void)testAESRejectsNegativeLengthsWithoutChangingDestinationOrIV {
    uint8_t key[32] = {0}, input[16] = {0}, out[16], iv[16] = {0};
    aes_encrypt_ctx enc;
    aes_decrypt_ctx dec;
    XCTAssertEqual(aes_encrypt_key256(key, &enc), 0);
    XCTAssertEqual(aes_decrypt_key256(key, &dec), 0);
    aes_encrypt_ctx originalEnc;
    aes_decrypt_ctx originalDec;
    memcpy(&originalEnc, &enc, sizeof(enc));
    memcpy(&originalDec, &dec, sizeof(dec));
    memcpy(out, input, sizeof(out));
    XCTAssertNotEqual(aes_ecb_encrypt(input, out, -16, &enc), 0);
    XCTAssertNotEqual(aes_ecb_decrypt(input, out, -16, &dec), 0);
    XCTAssertNotEqual(aes_cbc_encrypt(input, out, -16, iv, &enc), 0);
    XCTAssertNotEqual(aes_cbc_decrypt(input, out, -16, iv, &dec), 0);
    XCTAssertEqual(memcmp(out, input, sizeof(out)), 0);
    XCTAssertEqual(memcmp(iv, input, sizeof(iv)), 0);
    XCTAssertEqual(memcmp(&enc, &originalEnc, sizeof(enc)), 0);
    XCTAssertEqual(memcmp(&dec, &originalDec, sizeof(dec)), 0);
    XCTAssertEqual(aes_cbc_encrypt(input, out, 0, iv, &enc), 0);
    const uint8_t expected[16] = {0xdc,0x95,0xc0,0x78,0xa2,0x40,0x89,0x89,0xad,0x48,0xa2,0x14,0x92,0x84,0x20,0x87};
    XCTAssertEqual(aes_cbc_encrypt(input, out, 16, iv, &enc), 0);
    XCTAssertEqual(memcmp(out, expected, sizeof(out)), 0);
}
@end
