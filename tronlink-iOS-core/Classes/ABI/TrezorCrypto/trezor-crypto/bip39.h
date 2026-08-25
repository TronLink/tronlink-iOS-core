/**
 * Copyright (c) 2013-2014 Tomas Dzetkulic
 * Copyright (c) 2013-2014 Pavol Rusnak
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included
 * in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
 * OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
 * OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
 * ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */

#ifndef __BIP39_H__
#define __BIP39_H__

#include <stdint.h>

#define BIP39_PBKDF2_ROUNDS 2048
#define BIP39_MAX_WORDS 24
#define BIP39_MAX_WORD_LENGTH 9
// Bounded by the PBKDF2 salt buffer, not by BIP39 itself. Enforce the same limit on any
// passphrase input field so users are told up front rather than failing at derivation.
#define BIP39_MAX_PASSPHRASE_LENGTH 256

// buf/indexes are caller-owned. buflen must be at least BIP39_MAX_WORDS *
// (BIP39_MAX_WORD_LENGTH + 1); count must be at least BIP39_MAX_WORDS. For valid
// arguments, generation failure leaves buf zeroed or indexes filled with UINT16_MAX.
// The returned pointer must always be checked.
const char *mnemonic_generate(int strength, char *buf, int buflen) __attribute__((warn_unused_result));	// strength in bits
const uint16_t *mnemonic_generate_indexes(int strength, uint16_t *indexes, int count) __attribute__((warn_unused_result));	// strength in bits

const char *mnemonic_from_data(const uint8_t *data, int len, char *buf, int buflen);
const uint16_t *mnemonic_from_data_indexes(const uint8_t *data, int len, uint16_t *indexes, int count);

int mnemonic_check(const char *mnemonic);

int mnemonic_to_entropy(const char *mnemonic, uint8_t *entropy);

// Returns 1 on success. Returns 0 and leaves seed zeroed when either string is NULL or the
// passphrase exceeds BIP39_MAX_PASSPHRASE_LENGTH, so the result must be checked before use:
// an unchecked failure would derive every wallet from an all-zero seed.
int mnemonic_to_seed(const char *mnemonic, const char *passphrase, uint8_t seed[512 / 8], void (*progress_callback)(uint32_t current, uint32_t total)) __attribute__((warn_unused_result));

const char * const *mnemonic_wordlist(void);

#endif
