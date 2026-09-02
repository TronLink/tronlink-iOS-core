
@import Foundation;

@interface EthereumCrypto : NSObject

+ (BOOL)isValidPrivateKey:(nonnull NSData *)privateKey NS_SWIFT_NAME(isValidPrivateKey(_:));

/// Extracts the public key from a 32-byte private key.
/// Returns empty data unless the private key is a 32-byte scalar in the range 0 < k < curve order.
+ (nonnull NSData *)getPublicKeyFrom:(nonnull NSData *)privateKey NS_SWIFT_NAME(getPublicKey(from:));

+ (nonnull NSData *)getPublicKeyFrom:(nonnull NSData *)privateKey
                          compressed:(BOOL)compressed
NS_SWIFT_NAME(getPublicKey(from:compressed:));

+ (nonnull NSData *)uncompressPublicKey:(nonnull NSData *)publicKey
NS_SWIFT_NAME(uncompressPublicKey(_:));

+ (nonnull NSData *)recoverPublicKeyFromHash:(nonnull NSData *)hash
                                   signature:(nonnull NSData *)signature
                                  recoveryID:(uint8_t)recoveryID
                                  compressed:(BOOL)compressed
NS_SWIFT_NAME(recoverPublicKey(hash:signature:recoveryID:compressed:));

/// Computes the Ethereum hash of a block of data (SHA3 Keccak 256 version).
+ (nonnull NSData *)hash:(nonnull NSData *)hash;

/// Signs a hash with a private key.
///
/// @param hash 32-byte hash to sign
/// @param privateKey 32-byte private key in the range 0 < k < curve order
/// @return signature is in the 65-byte [R || S || V] format where V is the raw recovery ID in 0...3; empty data is returned for invalid input or signing failure.
+ (nonnull NSData *)signHash:(nonnull NSData *)hash privateKey:(nonnull NSData *)privateKey NS_SWIFT_NAME(sign(hash:privateKey:));

/// Verifies a hash signature.
///
/// @param signature 64-byte [R || S] or 65-byte [R || S || V] signature; the recovery byte is ignored
/// @param message 32-byte digest to verify
/// @param publicKey 33-byte compressed or 65-byte uncompressed public key
/// @return whether the inputs and signature are valid
+ (BOOL)verifySignature:(nonnull NSData *)signature message:(nonnull NSData *)message publicKey:(nonnull NSData *)publicKey NS_SWIFT_NAME(verify(signature:message:publicKey:));

+ (nonnull NSData *)sha256:(nonnull NSData *)data;

@end
