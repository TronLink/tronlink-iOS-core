#ifdef __OBJC__
#import <Foundation/Foundation.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

FOUNDATION_EXPORT double TrezorCryptoVersionNumber;
FOUNDATION_EXPORT const unsigned char TrezorCryptoVersionString[];

#include "trezor-crypto/aes/aes.h"
#include "trezor-crypto/chacha20poly1305/chacha20poly1305.h"
#include "trezor-crypto/ed25519-donna/ed25519-donna.h"
#include "trezor-crypto/address.h"
#include "trezor-crypto/base32.h"
#include "trezor-crypto/base58.h"
#include "trezor-crypto/bignum.h"
#include "trezor-crypto/bip32.h"
#include "trezor-crypto/bip39.h"
#include "trezor-crypto/blake256.h"
#include "trezor-crypto/blake2b.h"
#include "trezor-crypto/blake2s.h"
#include "trezor-crypto/cash_addr.h"
#include "trezor-crypto/curves.h"
#include "trezor-crypto/ecdsa.h"
#include "trezor-crypto/groestl.h"
#include "trezor-crypto/hasher.h"
#include "trezor-crypto/hmac.h"
#include "trezor-crypto/memzero.h"
#include "trezor-crypto/nem.h"
#include "trezor-crypto/nist256p1.h"
#include "trezor-crypto/pbkdf2.h"
#include "trezor-crypto/rand.h"
#include "trezor-crypto/rc4.h"
#include "trezor-crypto/rfc6979.h"
#include "trezor-crypto/chacha20poly1305/rfc7539.h"
#include "trezor-crypto/ripemd160.h"
#include "trezor-crypto/script.h"
#include "trezor-crypto/secp256k1.h"
#include "trezor-crypto/segwit_addr.h"
#include "trezor-crypto/sha2.h"
#include "trezor-crypto/sha3.h"
