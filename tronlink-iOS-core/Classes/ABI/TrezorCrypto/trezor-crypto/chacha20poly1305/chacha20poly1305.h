#ifndef CHACHA20POLY1305_H
#define CHACHA20POLY1305_H

#include <stdint.h>
#include "ecrypt-sync.h"
#include "poly1305-donna.h"

typedef struct {
    ECRYPT_ctx       chacha20;
    poly1305_context poly1305;
} chacha20poly1305_ctx;

// ECRYPT accepts 32-bit lengths and discards leftover keystream after each call.
static inline uint32_t chacha20poly1305_chunk_size(size_t remaining) {
    return remaining > UINT32_MAX ? UINT32_MAX - UINT32_MAX % 64u : (uint32_t)remaining;
}

void xchacha20poly1305_init(chacha20poly1305_ctx *ctx, uint8_t key[32], uint8_t nonce[24]);
void chacha20poly1305_encrypt(chacha20poly1305_ctx *ctx, uint8_t *in, uint8_t *out, size_t n);
void chacha20poly1305_decrypt(chacha20poly1305_ctx *ctx, uint8_t *in, uint8_t *out, size_t n);
void chacha20poly1305_auth(chacha20poly1305_ctx *ctx, uint8_t *in, size_t n);
void chacha20poly1305_finish(chacha20poly1305_ctx *ctx, uint8_t mac[16]);

#endif // CHACHA20POLY1305_H
