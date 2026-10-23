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

#include <string.h>
#include <stdbool.h>

#include "bip39.h"
#include "hmac.h"
#include "rand.h"
#include "sha2.h"
#include "pbkdf2.h"
#include "bip39_english.h"
#include "options.h"
#include "memzero.h"

const char *mnemonic_generate(int strength, char *buf, int buflen)
{
	if (strength % 32 || strength < 128 || strength > 256) {
		return 0;
	}
	if (!buf || buflen < BIP39_MAX_WORDS * (BIP39_MAX_WORD_LENGTH + 1)) {
		return 0;
	}
	const int data_len = strength / 8;
	uint8_t data[32] = {0};
	if (!random_buffer_checked(data, data_len)) {
		memzero(data, sizeof(data));
		memzero(buf, BIP39_MAX_WORDS * (BIP39_MAX_WORD_LENGTH + 1));
		return 0;
	}
	const char *r = mnemonic_from_data(data, data_len, buf, buflen);
	memzero(data, sizeof(data));
	return r;
}

const uint16_t *mnemonic_generate_indexes(int strength, uint16_t *indexes, int count)
{
	if (strength % 32 || strength < 128 || strength > 256) {
		return 0;
	}
	if (!indexes || count < BIP39_MAX_WORDS) {
		return 0;
	}
	const int data_len = strength / 8;
	uint8_t data[32] = {0};
	if (!random_buffer_checked(data, data_len)) {
		memzero(data, sizeof(data));
		memset(indexes, 0xFF, BIP39_MAX_WORDS * sizeof(*indexes));
		return 0;
	}
	const uint16_t *r = mnemonic_from_data_indexes(data, data_len, indexes, count);
	memzero(data, sizeof(data));
	return r;
}

const char *mnemonic_from_data(const uint8_t *data, int len, char *buf, int buflen)
{
	if (len % 4 || len < 16 || len > 32) {
		return 0;
	}
	if (!buf || buflen < BIP39_MAX_WORDS * (BIP39_MAX_WORD_LENGTH + 1)) {
		return 0;
	}

	uint8_t bits[32 + 1];

	sha256_Raw(data, len, bits);
	// checksum
	bits[len] = bits[0];
	// data
	memcpy(bits, data, len);

	int mlen = len * 3 / 4;

	int i, j, idx;
	char *p = buf;
	for (i = 0; i < mlen; i++) {
		idx = 0;
		for (j = 0; j < 11; j++) {
			idx <<= 1;
			idx += (bits[(i * 11 + j) / 8] & (1 << (7 - ((i * 11 + j) % 8)))) > 0;
		}
		strcpy(p, wordlist[idx]);
		p += strlen(wordlist[idx]);
		*p = (i < mlen - 1) ? ' ' : 0;
		p++;
	}
	memzero(bits, sizeof(bits));

	return buf;
}

const uint16_t *mnemonic_from_data_indexes(const uint8_t *data, int len, uint16_t *indexes, int count)
{
	if (len % 4 || len < 16 || len > 32) {
		return 0;
	}
	if (!indexes || count < BIP39_MAX_WORDS) {
		return 0;
	}

	uint8_t bits[32 + 1];

	sha256_Raw(data, len, bits);
	// checksum
	bits[len] = bits[0];
	// data
	memcpy(bits, data, len);

	int mlen = len * 3 / 4;

	int i, j, idx;
	for (i = 0; i < mlen; i++) {
		idx = 0;
		for (j = 0; j < 11; j++) {
			idx <<= 1;
			idx += (bits[(i * 11 + j) / 8] & (1 << (7 - ((i * 11 + j) % 8)))) > 0;
		}
		indexes[i] = idx;
	}
	memzero(bits, sizeof(bits));

	return indexes;
}

int mnemonic_to_entropy(const char *mnemonic, uint8_t *entropy)
{
	if (!mnemonic) {
		return 0;
	}

	uint32_t i = 0, n = 0;

	while (mnemonic[i]) {
		if (mnemonic[i] == ' ') {
			n++;
		}
		i++;
	}
	n++;

	// check number of words
	if (n < 12 || n > 24 || n % 3 != 0) {
		return 0;
	}

	char current_word[10];
	uint32_t j, k, ki, bi = 0;
	uint8_t bits[32 + 1];

	memzero(bits, sizeof(bits));
	i = 0;
	while (mnemonic[i]) {
		j = 0;
		while (mnemonic[i] != ' ' && mnemonic[i] != 0) {
			if (j >= sizeof(current_word) - 1) {
				return 0;
			}
			current_word[j] = mnemonic[i];
			i++; j++;
		}
		current_word[j] = 0;
		if (mnemonic[i] != 0) {
			i++;
		}
		k = 0;
		for (;;) {
			if (!wordlist[k]) { // word not found
				return 0;
			}
			if (strcmp(current_word, wordlist[k]) == 0) { // word found on index k
				for (ki = 0; ki < 11; ki++) {
					if (k & (1 << (10 - ki))) {
						bits[bi / 8] |= 1 << (7 - (bi % 8));
					}
					bi++;
				}
				break;
			}
			k++;
		}
	}
	if (bi != n * 11) {
		return 0;
	}
	memcpy(entropy, bits, sizeof(bits));
	return n * 11;
}

int mnemonic_check(const char *mnemonic)
{
	uint8_t bits[32 + 1];
	int seed_len = mnemonic_to_entropy(mnemonic, bits);
	if (!seed_len) {
		return 0;
	}
	int words = seed_len / 11;

	uint8_t checksum = bits[words * 4 / 3];
	sha256_Raw(bits, words * 4 / 3, bits);
	int checksum_bits = words / 3;
	return (bits[0] >> (8 - checksum_bits)) == (checksum >> (8 - checksum_bits));
}

int mnemonic_to_seed(const char *mnemonic, const char *passphrase, uint8_t seed[512 / 8], void (*progress_callback)(uint32_t current, uint32_t total))
{
	memzero(seed, 512 / 8);
	if (!mnemonic || !passphrase) {
		return 0;
	}
	size_t passphraselen = strlen(passphrase);
	if (passphraselen > BIP39_MAX_PASSPHRASE_LENGTH) {
		return 0;
	}
	uint8_t salt[8 + BIP39_MAX_PASSPHRASE_LENGTH];
	memcpy(salt, "mnemonic", 8);
	memcpy(salt + 8, passphrase, passphraselen);
	CONFIDENTIAL PBKDF2_HMAC_SHA512_CTX pctx;
	pbkdf2_hmac_sha512_Init(&pctx, (const uint8_t *)mnemonic, strlen(mnemonic), salt, (int)passphraselen + 8, 1);
	if (progress_callback) {
		progress_callback(0, BIP39_PBKDF2_ROUNDS);
	}
	for (int i = 0; i < 16; i++) {
		pbkdf2_hmac_sha512_Update(&pctx, BIP39_PBKDF2_ROUNDS / 16);
		if (progress_callback) {
			progress_callback((i + 1) * BIP39_PBKDF2_ROUNDS / 16, BIP39_PBKDF2_ROUNDS);
		}
	}
	pbkdf2_hmac_sha512_Final(&pctx, seed);
	memzero(salt, sizeof(salt));
	return 1;
}

const char * const *mnemonic_wordlist(void)
{
	return wordlist;
}
