
import Foundation

/// Scrypt function parameters.
///
/// - Note (TL-KDF-001, 2026-08 audit):
///   The historical default was `n = lightN (4096), p = lightP (6)` (≈4 MiB), which
///   is the go-ethereum "light" preset. That is too weak to meaningfully slow down
///   offline brute-force of weak user passwords if the keystore ever leaves the
///   device (e.g. forensic dump, user manually exports and stores insecurely).
///   The default is now `balancedN / balancedP` (≈64 MiB, ~250–500 ms on modern
///   iPhones, ~1 s on the oldest iOS 15.1 device). We deliberately do NOT jump to
///   `standardN` (256 MiB) because that will OOM low-end supported devices.
///
/// - Note (thread & memory safety):
///   Each call site (`KeystoreKeyHeader.init(password:data:)`,
///   `KeystoreKey.decrypt(password:)`) instantiates a fresh `Scrypt` object per
///   invocation, so this struct itself is used only from one thread at a time.
///   However raising N by 16× also raises peak RAM per concurrent scrypt run
///   from ~4 MiB to ~64 MiB. If the KeyStore/TrezorCrypto call sites are ever
///   invoked concurrently (see IOS-CONC-001), two overlapping runs already cost
///   ≥128 MiB, which is close to the foreground budget on iPhone 6s. Serialize
///   the KeyStore layer alongside the IOS-CONC-001 fix.
public struct ScryptParams {
    /// Ethereum "standard" preset. Uses ≈256 MiB and ~1 s CPU on a modern desktop.
    /// Not used as the mobile default — OOMs on low-end supported devices.
    public static let standardN = 1 << 18

    /// Parallelization factor paired with `standardN`.
    public static let standardP = 1

    /// Balanced mobile default (TL-KDF-001).
    /// Peak RAM ≈ 128 * r * n = 128 * 8 * 65536 = 64 MiB.
    /// Target CPU ≈ 250–500 ms on modern iPhones, ~1 s on iPhone 6s (iOS 15.1 floor).
    public static let balancedN = 1 << 16

    /// Parallelization factor paired with `balancedN`.
    /// Matches ethereum's canonical `p = 1`, so the resulting JSON stays
    /// round-trippable with any standards-compliant wallet.
    public static let balancedP = 1

    /// Ethereum "light" preset. Uses ≈4 MiB and ~100 ms CPU on a modern desktop.
    /// Retained for backward-compat (decoding files produced with these params
    /// still works via the per-file kdfparams) and for explicit callers that need
    /// the historical value; do NOT reintroduce it as the default (see TL-KDF-001).
    public static let lightN = 1 << 12

    /// Parallelization factor paired with `lightN`.
    public static let lightP = 6

    /// Default `R` parameter of Scrypt encryption algorithm.
    public static let defaultR = 8

    /// Default desired key length of Scrypt encryption algorithm.
    public static let defaultDesiredKeyLength = 32

    /// Upper bound on scrypt's peak working memory, which is `128 * r * n` bytes.
    ///
    /// go-ethereum's `standardN` preset (n = 262144, r = 8) needs 256 MiB and is the
    /// strongest configuration desktop wallets actually produce, so this leaves one
    /// doubling of headroom above it for anything unusual a user might import. Past this
    /// point the allocation could not complete on a supported device anyway: the three
    /// `UnsafeMutableRawPointer.allocate` calls in `Scrypt.scrypt` abort the process on
    /// failure rather than throwing, so an unbounded `n` is an uncatchable crash, not a
    /// feature (see TL-KDF-002).
    public static let maxMemoryBytes = 512 * 1024 * 1024

    /// Flat ceiling on the cost factor, matching Android's `1048576`. The `maxMemoryBytes`
    /// rule is the stricter of the two once `r >= 8`, but at `r = 1` it would allow 2^22 —
    /// looser than Android. Both bounds apply, so the clients cannot diverge in either
    /// direction on `n`.
    public static let maxN = 1 << 20

    /// Upper bound on the block size factor. Every preset in use sets `r = 8`; the wider
    /// range exists only to match Android (see the note on `maxP`). Large `r` cannot
    /// exhaust memory on its own because `maxMemoryBytes` caps `128 * r * n`.
    public static let maxR = 64

    /// Upper bound on the parallelization factor.
    ///
    /// - Note (TL-KDF-002, double-ended alignment):
    ///   These three limits mirror the Android client's `org.tron.net.KeyStoreUtils`,
    ///   which rejects `r` outside 1...64, `p` outside 1...16 and `dklen` outside
    ///   32...1024. A keystore is a file users move between the two apps, so the same
    ///   file has to be accepted or refused on both. Only `n` intentionally stays
    ///   stricter here: Android caps it at a flat 2^20, which at `r = 8` asks for 1 GiB
    ///   and would be killed by jetsam on iOS, so `n` remains bounded by
    ///   `maxMemoryBytes` instead. Widening `p` costs CPU time only — it never enters
    ///   the `128 * r * n` allocation.
    public static let maxP = 16

    /// Minimum derived-key length. `KeystoreKey.decrypt` takes the leading 16 bytes as
    /// the AES key and the trailing 16 bytes as the MAC prefix, so a shorter derived
    /// key makes those two slices overlap or read out of bounds.
    public static let minDesiredKeyLength = 32

    /// Upper bound on the derived-key length. No standard V3 keystore exceeds 32; the
    /// headroom matches Android. Extra length is merely discarded by `decrypt`.
    public static let maxDesiredKeyLength = 1024

    /// Random salt.
    public var salt: Data

    /// Desired key length in bytes.
    public var desiredKeyLength = defaultDesiredKeyLength

    /// CPU/Memory cost factor. Defaults to `balancedN` (TL-KDF-001).
    public var n = balancedN

    /// Parallelization factor (1..232-1 * hLen/MFlen). Defaults to `balancedP`.
    public var p = balancedP

    /// Block size factor.
    public var r = defaultR

    /// Initializes with default scrypt parameters and a random salt.
    public init() {
        let length = 32
        var data = Data(repeating: 0, count: length)
        let result = data.withUnsafeMutableBytes { p in
            SecRandomCopyBytes(kSecRandomDefault, length, p)
        }
        precondition(result == errSecSuccess, "Failed to generate random number")
        salt = data
    }

    /// Initializes `ScryptParams` with all values.
    public init(salt: Data, n: Int, r: Int, p: Int, desiredKeyLength: Int) throws {
        self.salt = salt
        self.n = n
        self.r = r
        self.p = p
        self.desiredKeyLength = desiredKeyLength
        if let error = validate() {
            throw error
        }
    }

    /// Validates the parameters.
    ///
    /// This is the single gate in front of `Scrypt.calculate`, and `init(from:)` decodes
    /// `n` / `r` / `p` / `dklen` straight out of keystore JSON, so every value reaching
    /// this function must be treated as attacker-controlled.
    ///
    /// - Note (TL-KDF-002, 2026-08 audit):
    ///   The previous implementation converted to `UInt64` and divided by `p` and `r`
    ///   *before* establishing that they were positive, so `r = -1`, `r = 0` and `p = 0`
    ///   trapped inside this very function instead of being rejected — an uncatchable
    ///   crash on a malformed import. It also let two dangerous configurations through:
    ///   `dklen = 0`, which made `KeystoreKey.decrypt` slice out of bounds, and any
    ///   power-of-two `n` large enough to ask scrypt for terabytes while still passing
    ///   the `Int.max` overflow guard. The order below is load-bearing: positivity is
    ///   established first, and every later division uses a divisor already known to be
    ///   positive and bounded.
    ///
    /// - Returns: a `ValidationError` or `nil` if the parameters are valid.
    public func validate() -> ValidationError? {
        // Positivity first. Everything after this point either divides by one of these
        // values or relies on them not being negative.
        guard n > 1, r > 0, p > 0 else {
            return ValidationError.nonPositiveParameter
        }
        // Android refuses a keystore with no scrypt salt outright; deriving from an empty
        // salt would otherwise make the KDF output depend on the password alone.
        if salt.isEmpty {
            return ValidationError.emptySalt
        }
        if desiredKeyLength < ScryptParams.minDesiredKeyLength {
            return ValidationError.desiredKeyLengthTooSmall
        }
        if desiredKeyLength > ScryptParams.maxDesiredKeyLength {
            return ValidationError.desiredKeyLengthTooLarge
        }
        if n & (n - 1) != 0 || n > ScryptParams.maxN {
            return ValidationError.invalidCostFactor
        }
        if r > ScryptParams.maxR || p > ScryptParams.maxP {
            return ValidationError.blockSizeTooLarge
        }
        // `r` is positive and bounded above by now, so this division is safe, and it caps
        // `n` before `128 * r * n` can overflow or reach the allocator.
        if n > ScryptParams.maxMemoryBytes / 128 / r {
            return ValidationError.overflow
        }
        return nil
    }

    public enum ValidationError: Error {
        case desiredKeyLengthTooLarge
        case blockSizeTooLarge
        case invalidCostFactor
        case overflow
        /// `n`, `r` or `p` was zero or negative (TL-KDF-002).
        case nonPositiveParameter
        /// `dklen` was shorter than the 32 bytes `KeystoreKey.decrypt` slices (TL-KDF-002).
        case desiredKeyLengthTooSmall
        /// The keystore carried no scrypt salt (TL-KDF-002).
        case emptySalt
    }
}

extension ScryptParams: Codable {
    enum CodingKeys: String, CodingKey {
        case salt
        case desiredKeyLength = "dklen"
        case n
        case p
        case r
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        salt = try values.decodeHexString(forKey: .salt)
        desiredKeyLength = try values.decode(Int.self, forKey: .desiredKeyLength)
        n = try values.decode(Int.self, forKey: .n)
        p = try values.decode(Int.self, forKey: .p)
        r = try values.decode(Int.self, forKey: .r)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(salt.hexString, forKey: .salt)
        try container.encode(desiredKeyLength, forKey: .desiredKeyLength)
        try container.encode(n, forKey: .n)
        try container.encode(p, forKey: .p)
        try container.encode(r, forKey: .r)
    }
}

