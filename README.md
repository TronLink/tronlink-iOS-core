# tronlink-iOS-core

TronLink Wallet is a decentralized non-custodial wallet.TronLink-Core is the core module of TronLink Wallet, which provides core functions such as Create Wallet, Get Address and Sign Transaction.

## Analytics Module (Privacy-First Design)

The `Metrics` module collects aggregated usage data only. **Wallet addresses, keys, mnemonics, transaction hashes, counter-parties, and device identifiers are never transmitted.** The backend receives only opaque UUIDs and same-day aggregated buckets; individual transactions are not reconstructible.

### Address → UUID Anonymization

Each address is mapped to a random UUID stored **locally only** (FMDB, with migration from legacy `UserDefaults`). The backend never sees the address, and the same user's two wallets appear as two independent UUIDs (no server-side linkage).

```swift
// TRXAddressMapManager.swift — local-only address → uuid mapping
public func id(for address: String) -> String {
    let normalized = Self.normalizeAddress(address)
    var existing: String?
    queue.sync { existing = mapping[normalized] }
    if let v = existing { return v }

    var result = ""
    var needsSave = false
    queue.sync(flags: .barrier) {
        if let v = self.mapping[normalized] { result = v; return }
        var candidate = Self.generateUUIDFull()            // UUID().uuidString
        while self.usedIds.contains(candidate) { candidate = Self.generateUUIDFull() }
        self.mapping[normalized] = candidate
        self.usedIds.insert(candidate)
        result = candidate
        needsSave = true
    }
    if needsSave {
        DispatchQueue.global(qos: .utility).async {
            TRXMetricsDBManager.shared.saveAddressMappings(self.allMappings()) // on-device only
        }
    }
    return result
}
```

### What Is Uploaded

Records are merged locally per `(uid, actionType, tokenAddress, day)` before upload, and raw amounts are replaced with a 9-bucket logarithmic histogram (`A1..A9`).

Never collected, never transmitted:

 • Wallet addresses , Public keys, Mnemonic phrases, Private keys.

 • Transaction hashes , Contract call parameters.

 • IP, device fingerprint,  any identifier derived from the host browser.


## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Requirements

- iOS 13.0+
- Swift 4.2

## Installation

tronlink-iOS-core is available through [CocoaPods](https://cocoapods.org). To install it, simply add the following line to your Podfile:

```ruby
pod 'tronlink-iOS-core'
```

## Demo

- [Create wallet](./Example/Tests/Tests.swift)
- [Sign transaction](./Example/Tests/Tests.swift)
- [Sign message](./Example/Tests/Tests.swift)
- [Export PrivateKey](./Example/Tests/Tests.swift)
- [Export Mnemonic](./Example/Tests/Tests.swift)


