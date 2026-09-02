
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

+ (BOOL)isValidPrivateKey:(nonnull NSData *)privateKey {
    return isValidPrivateKeyData(privateKey);
}

+ (nonnull NSData *)getPublicKeyFrom:(nonnull NSData *)privateKey {
    return [self getPublicKeyFrom:privateKey compressed:NO];
}

+ (nonnull NSData *)getPublicKeyFrom:(nonnull NSData *)privateKey compressed:(BOOL)compressed {
    if (!isValidPrivateKeyData(privateKey)) {
        return [NSData data];
    }
    NSUInteger length = compressed ? 33 : 65;
    NSMutableData *publicKey = [[NSMutableData alloc] initWithLength:length];
    if (compressed) {
        ecdsa_get_public_key33(&secp256k1, privateKey.bytes, publicKey.mutableBytes);
    } else {
        ecdsa_get_public_key65(&secp256k1, privateKey.bytes, publicKey.mutableBytes);
    }
    return publicKey;
}

+ (nonnull NSData *)uncompressPublicKey:(nonnull NSData *)publicKey {
    if (publicKey.length != 33) {
        return [NSData data];
    }
    uint8_t prefix = ((const uint8_t *)publicKey.bytes)[0];
    if (prefix != 0x02 && prefix != 0x03) {
        return [NSData data];
    }
    NSMutableData *uncompressed = [[NSMutableData alloc] initWithLength:65];
    if (ecdsa_uncompress_pubkey(&secp256k1, publicKey.bytes, uncompressed.mutableBytes) != 1) {
        memzero(uncompressed.mutableBytes, uncompressed.length);
        return [NSData data];
    }
    return uncompressed;
}

+ (nonnull NSData *)recoverPublicKeyFromHash:(nonnull NSData *)hash
                                   signature:(nonnull NSData *)signature
                                  recoveryID:(uint8_t)recoveryID
                                  compressed:(BOOL)compressed {
    if (hash.length != 32 || signature.length != 64 || recoveryID > 3) {
        return [NSData data];
    }
    uint8_t uncompressed[65] = {0};
    if (ecdsa_recover_pub_from_sig(&secp256k1, uncompressed, signature.bytes, hash.bytes, recoveryID) != 0) {
        memzero(uncompressed, sizeof(uncompressed));
        return [NSData data];
    }
    if (compressed) {
        NSMutableData *publicKey = [[NSMutableData alloc] initWithLength:33];
        uint8_t *bytes = publicKey.mutableBytes;
        bytes[0] = 0x02 | (uncompressed[64] & 1);
        memcpy(bytes + 1, uncompressed + 1, 32);
        memzero(uncompressed, sizeof(uncompressed));
        return publicKey;
    }
    NSData *publicKey = [NSData dataWithBytes:uncompressed length:sizeof(uncompressed)];
    memzero(uncompressed, sizeof(uncompressed));
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
