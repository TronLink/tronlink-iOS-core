/**
 * Copyright (c) 2016 Pavol Rusnak
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
#include "base58.h"
#include "script.h"
#include "segwit_addr.h"

int script_output_to_address(const uint8_t *script, int scriptlen, char *addr, int addrsize)
{
	if (script == NULL || addr == NULL || scriptlen <= 0 || addrsize <= 0) {
		return 0;
	}
	uint8_t raw[21];

	// P2PKH
	if (scriptlen == 25 && script[0] == 0x76 && script[1] == 0xA9 && script[2] == 0x14 && script[23] == 0x88 && script[24] == 0xAC) {
		raw[0] = 0x00;
		memcpy(raw + 1, script + 3, 20);
		return base58_encode_check(raw, 1 + 20, HASHER_SHA2D, addr, addrsize);
	}

	// P2SH
	if (scriptlen == 23 && script[0] == 0xA9 && script[1] == 0x14 && script[22] == 0x87) {
		raw[0] = 0x05;
		memcpy(raw + 1, script + 2, 20);
		return base58_encode_check(raw, 1 + 20, HASHER_SHA2D, addr, addrsize);
	}

	// Native P2WPKH/P2WSH, on the same Bitcoin mainnet as the legacy branches.
	if ((scriptlen == 22 && script[0] == 0x00 && script[1] == 0x14) ||
	    (scriptlen == 34 && script[0] == 0x00 && script[1] == 0x20)) {
		// segwit_addr_encode has no capacity argument. Encode into its documented
		// maximum buffer first, then copy only if the caller has enough space.
		char encoded[73 + 2]; // 73 + strlen("bc")
		if (!segwit_addr_encode(encoded, "bc", 0, script + 2, scriptlen - 2)) {
			return 0;
		}
		size_t length = strlen(encoded) + 1;
		if ((size_t)addrsize < length) {
			return 0;
		}
		memcpy(addr, encoded, length);
		return (int)length; // Match base58_encode_check: include the terminating NUL.
	}

	return 0;
}
