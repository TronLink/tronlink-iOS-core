#ifndef TL_MNEMONIC_WORDLIST_H
#define TL_MNEMONIC_WORDLIST_H

#ifdef __cplusplus
extern "C" {
#endif

// Borrowed, NULL-terminated English BIP39 word list with process lifetime.
__attribute__((visibility("default")))
const char * const *mnemonic_wordlist(void);

#ifdef __cplusplus
}
#endif
#endif
