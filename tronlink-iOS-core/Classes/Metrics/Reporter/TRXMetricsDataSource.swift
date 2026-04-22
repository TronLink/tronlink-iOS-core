import Foundation

public protocol TRXMetricsDataSource: AnyObject {
    /// Environment key for the current chain, e.g. "MainNet", "Nile", etc.
    var environmentKey: String { get }
    
    /// Indicates if the current environment is Shasta
    var isShastaEnvironment: Bool { get }
    
    /// Indicates if the current wallet is a watch wallet
    var isWatchWallet: Bool { get }
    
    /// Indicates if the basic function is open
    var isBasicFunctionOpen: Bool { get }
    
    /// Indicates if token cloud synchronization is closed
    var isTokenCloudSyncClose: Bool { get }
    
    /// The address of the current active wallet
    var walletAddress: String { get }
    
    /// Wallet type for statistical metrics
    var uploadWalletType: Int { get }
    
    /// USDT contract address
    var usdtContractAddress: String { get }
    
    /// Indicates if the current environment is online
    var isOnlineEnvironment: Bool { get }
    
    /// Indicates if the current environment is pre-release
    var isPreReleaseEnvironment: Bool { get }
    
    /// Delegate network request for uploading statistical data
    func uploadStatisticalData(parameters: [String: Any], visible: Bool, success: @escaping (Bool, Bool) -> Void, failure: @escaping () -> Void)
    
    // MARK: - Legacy Migration (optional, default implementations provided below)
    
    /// Returns asset records that need to be uploaded from the old database.
    /// Default returns nil (no legacy data). Override only when migrating from an older version.
    func legacyUpdatedAssetSyncModels(forChain chain: String) -> [TRXAssetSyncModel]?
    
    /// Returns transaction records that need to be uploaded from the old database.
    /// Default returns nil (no legacy data). Override only when migrating from an older version.
    func legacyUpdatedTransactionSyncModels(forChain chain: String) -> [TRXTransactionSyncModel]?
}

// MARK: - Default implementations (migration methods are opt-in)
public extension TRXMetricsDataSource {
    
    func legacyUpdatedAssetSyncModels(forChain chain: String) -> [TRXAssetSyncModel]? {
        return nil
    }
    
    func legacyUpdatedTransactionSyncModels(forChain chain: String) -> [TRXTransactionSyncModel]? {
        return nil
    }
}
