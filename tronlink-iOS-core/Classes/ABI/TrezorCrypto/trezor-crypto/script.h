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

#ifndef __SCRIPT_H__
#define __SCRIPT_H__

#include <stdint.h>

/* Convert a Bitcoin MAINNET output script to its address.
 * Supports P2PKH/P2SH (Base58Check) and native v0 P2WPKH/P2WSH (Bech32, "bc").
 * Scripts do not identify their network; this legacy API is mainnet-only.
 * For witness addresses on other networks, use segwit_addr_encode with an
 * explicitly selected HRP instead. This is not a TRON address conversion API.
 * addrsize includes the terminating NUL: v0 witness addresses need 43 or 63 bytes.
 * Returns the address size INCLUDING the NUL on success, or 0 for invalid input,
 * unsupported scripts or insufficient capacity. On failure, addr is unchanged.
 */
int script_output_to_address(const uint8_t *script, int scriptlen, char *addr, int addrsize);

#endif
