
import Foundation

extension DerivationPath {
    /// Derivation path index.
    public struct Index: Hashable, CustomStringConvertible {
        /// Index value. Canonical path components use 0...0x7fffffff.
        /// Legacy values with the hardened bit already set are preserved for wallet recovery.
        public var value: Int

        /// Whether to set the hardened bit (a legacy value may already have it set).
        public var hardened: Bool

        /// The encoded child index, or nil if the value cannot be represented as UInt32.
        public var derivationIndex: UInt32? {
            guard let index = UInt32(exactly: value) else {
                return nil
            }
            return hardened ? index | 0x80000000 : index
        }

        public init(_ value: Int, hardened: Bool = true) {
            self.value = value
            self.hardened = hardened
        }

        public var hashValue: Int {
            return value.hashValue ^ hardened.hashValue
        }

        public static func == (lhs: Index, rhs: Index) -> Bool {
            return lhs.value == rhs.value && lhs.hardened == rhs.hardened
        }

        public var description: String {
            if hardened {
                return "\(value)'"
            } else {
                return value.description
            }
        }
    }
}
