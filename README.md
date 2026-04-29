# tronlink-iOS-core

TronLink Wallet is a decentralized non-custodial wallet.TronLink-Core is the core module of TronLink Wallet, which provides core functions such as Create Wallet, Get Address and Sign Transaction.

## Privacy

TronLink iOS only transmits aggregated, anonymized usage statistics. **Wallet addresses, private keys, mnemonics, transaction hashes, counter-parties, IPs, and device identifiers are never transmitted.** The backend receives only opaque per-address UUIDs minted on-device, plus same-day aggregated counts and 9-bucket logarithmic amount histograms — individual transactions cannot be reconstructed.

Reporting is gated by an in-app **Basic Mode** toggle in TronLink iOS Settings, plus automatic suppression for watch-only wallets, the Shasta test network, and non-release environments. When Basic Mode is **on**, no payload is built and no request is made.

For full details — what is collected, what is never collected, how anonymization / aggregation / encryption work, retention, and your controls — see [PRIVACY-POLICY.md](./PRIVACY-POLICY.md).


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


