
#import "EthereumCrypto.h"
#import "TrezorCrypto.h"

/// scalar_multiply() only guards 0 < k < order with assert(), which NDEBUG compiles out.
static BOOL isValidPrivateKeyData(NSData *privateKey) {
    if (privateKey.length != 32) {
        return NO;
    }
    bignum256 k;
    bn_read_be(privateKey.bytes, &k);
    BOOL valid = !bn_is_zero(&k) && bn_is_less(&k, &secp256k1.order);
    memzero(&k, sizeof(k));
    return valid;
}

static BOOL isValidPublicKeyData(NSData *publicKey) {
    if (publicKey.length != 33 && publicKey.length != 65) {
        return NO;
    }
    uint8_t prefix = ((const uint8_t *)publicKey.bytes)[0];
    return (publicKey.length == 33 && (prefix == 0x02 || prefix == 0x03)) ||
           (publicKey.length == 65 && prefix == 0x04);
}

@implementation EthereumCrypto

+ (nonnull NSData *)getPublicKeyFrom:(nonnull NSData *)privateKey {
    if (!isValidPrivateKeyData(privateKey)) {
        return [NSData data];
    }
    NSMutableData *publicKey = [[NSMutableData alloc] initWithLength:65];
    ecdsa_get_public_key65(&secp256k1, privateKey.bytes, publicKey.mutableBytes);
    return publicKey;
}

+ (nonnull NSData *)hash:(nonnull NSData *)hash {
    NSMutableData *output = [[NSMutableData alloc] initWithLength:sha3_256_hash_size];
    keccak_256(hash.bytes, hash.length, output.mutableBytes);
    return output;
}

+ (nonnull NSData *)signHash:(nonnull NSData *)hash privateKey:(nonnull NSData *)privateKey {
    if (hash.length != 32 || !isValidPrivateKeyData(privateKey)) {
        return [NSData data];
    }
    NSMutableData *signature = [[NSMutableData alloc] initWithLength:65];
    uint8_t by = 0;
    if (ecdsa_sign_digest(&secp256k1, privateKey.bytes, hash.bytes, signature.mutableBytes, &by, nil) != 0) {
        memzero(signature.mutableBytes, signature.length);
        return [NSData data];
    }
    ((uint8_t *)signature.mutableBytes)[64] = by;
    return signature;
}

+ (BOOL)verifySignature:(nonnull NSData *)signature message:(nonnull NSData *)message publicKey:(nonnull NSData *)publicKey {
    // ecdsa_verify_digest reads R || S only; a trailing recovery byte is accepted but unused.
    if ((signature.length != 64 && signature.length != 65) || message.length != 32 || !isValidPublicKeyData(publicKey)) {
        return NO;
    }
    return ecdsa_verify_digest(&secp256k1, publicKey.bytes, signature.bytes, message.bytes) == 0;
}

+ (nonnull NSData *)sha256:(nonnull NSData *)data {
    NSMutableData *result = [[NSMutableData alloc] initWithLength:SHA256_DIGEST_LENGTH];
    sha256_Raw(data.bytes, data.length, result.mutableBytes);
    return result;
}
@end
