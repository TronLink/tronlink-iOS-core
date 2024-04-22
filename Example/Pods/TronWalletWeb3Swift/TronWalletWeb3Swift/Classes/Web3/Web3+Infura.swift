
import BigInt
import Foundation

extension URL {
    static func infura(_ network: NetworkId, token: String? = nil) -> URL {
        var url = URL(string: "https://\(network).infura.io/")!
        if let token = token {
            url.appendPathComponent(token)
        }
        return url
    }
}

/**
 Custom Web3 HTTP provider of Infura nodes.
 web3swift uses Infura mainnet as default provider
 */
public final class InfuraProvider: Web3HttpProvider {
    /**
     - Parameter net: Defines network id. applies to address "https://\(net).infura.io/"
     - Parameter token: Your infura token. appends to url address
     - Parameter manager: KeystoreManager for this provider
     */
    public init?(_ net: NetworkId, accessToken token: String? = nil, keystoreManager manager: KeystoreManager = KeystoreManager()) {
        super.init(.infura(net, token: token), network: net, keystoreManager: manager)
    }
}
