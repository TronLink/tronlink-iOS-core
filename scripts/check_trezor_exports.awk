# Input is Darwin nm -mU output for one architecture.
/ external / && !/private external/ {
    if ($NF == "_mnemonic_wordlist") {
        found_wordlist = 1
    } else if ($NF ~ /^_(mnemonic_|hdnode_|ed25519_|ecdh_multiply$|ecdsa_|expand256_modm|pbkdf2_hmac_|aes_|(x?chacha20poly1305|rfc7539)_|random32$)/) {
        print "internal Trezor API exported: " $NF
        leaked = 1
    }
}
END {
    if (!found_wordlist) print "missing public mnemonic_wordlist"
    exit (leaked || !found_wordlist)
}
