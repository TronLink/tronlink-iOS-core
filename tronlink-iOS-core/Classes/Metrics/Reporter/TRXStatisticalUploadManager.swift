import Foundation

let Metrics_Statistical_Upload_Visible_Key = "TRXStatisticalUploadVisibleKey"

public class TRXStatisticalUploadManager: NSObject {
    public enum ParameterProcessingError: Error {
        case invalidEncryptionInputs
        case encryptionFailed
    }

    @objc public static let shared = TRXStatisticalUploadManager()
    private static let amountBuckets: [(threshold: NSDecimalNumber, idx: Int)] = [
        (NSDecimalNumber(string: "1"), 0),
        (NSDecimalNumber(string: "10"), 1),
        (NSDecimalNumber(string: "100"), 2),
        (NSDecimalNumber(string: "1000"), 3),
        (NSDecimalNumber(string: "10000"), 4),
        (NSDecimalNumber(string: "100000"), 5),
        (NSDecimalNumber(string: "1000000"), 6),
        (NSDecimalNumber(string: "10000000"), 7)
    ]
    private static let bucketKeyPaths: [WritableKeyPath<TRXTransactionSyncModel, Int?>] = [
        \TRXTransactionSyncModel.A1,
        \TRXTransactionSyncModel.A2,
        \TRXTransactionSyncModel.A3,
        \TRXTransactionSyncModel.A4,
        \TRXTransactionSyncModel.A5,
        \TRXTransactionSyncModel.A6,
        \TRXTransactionSyncModel.A7,
        \TRXTransactionSyncModel.A8,
        \TRXTransactionSyncModel.A9
    ]
    
    /// Dedicated serial background queue for all DB and upload operations.
    private let metricsQueue = DispatchQueue(label: "com.tronlink.metrics", qos: .utility)
    
    private override init() {}
    
    //MARK: -Required parameters, passed when the app starts.
    public var dataConfig: TRXMetricsDataSource?

    func isCollectionDisabled(_ config: TRXMetricsDataSource?) -> Bool {
        guard let config = config else { return true }
        return config.isShastaEnvironment || config.isWatchWallet || config.isBasicFunctionOpen ||
            config.isTokenCloudSyncClose || config.environmentKey.isEmpty || config.walletAddress.isEmpty
    }

    func isCurrentCollectionConfig(_ config: TRXMetricsDataSource, chain: String, walletAddress: String) -> Bool {
        // Compare by value (chain/address) instead of object identity, since the host may
        // legitimately replace dataConfig with a new instance carrying the same chain/address.
        guard let currentConfig = dataConfig, !isCollectionDisabled(currentConfig) else { return false }
        return currentConfig.environmentKey == chain && currentConfig.walletAddress == walletAddress &&
            config.environmentKey == chain && config.walletAddress == walletAddress
    }
    
    
    //MARK: -assets
    func getCurrentChainUpdatedIsTrueAllAssetSyncModels(forChain chain: String) -> [TRXAssetSyncModel] {
        let assets = TRXMetricsDBManager.shared.getUpdatedAssetSyncModels(forChain: chain)
        return assets
    }
    
    
    func upsertAssetDataCompareAndUpsert(model:TRXAssetSyncModel, callBackUpdate:Bool) {
        guard !isCollectionDisabled(dataConfig) else { return }
        TRXMetricsDBManager.shared.upsertAssetSync_compareAndUpsert(model: model, callBackUpdate: callBackUpdate)
    }
    
    
    public func upsertAssetData(model:TRXAssetSyncModel, callBackUpdate:Bool=false) {
        guard !isCollectionDisabled(dataConfig) else { return }
        if callBackUpdate {
            model.updated = false
            TRXMetricsDBManager.shared.upsertAssetSync(model: model)
        }else{
            let chain = model.chain ?? ""
            let uId = model.uId ?? ""
            let date = model.date ?? ""
            let m = TRXMetricsDBManager.shared.getAssetSyncModel(chain: chain, uId: uId, date: date)
            if let tm = m {
                let oldTrxBalance = (tm.trxBalance ?? "").tronCore_removeFloatSuffixZero()
                let oldUsdtBalance = (tm.usdtBalance ?? "").tronCore_removeFloatSuffixZero()
                let newTrxBalance = (model.trxBalance ?? "").tronCore_removeFloatSuffixZero()
                let newUsdtBalance = (model.usdtBalance ?? "").tronCore_removeFloatSuffixZero()
                if (oldTrxBalance.count > 0 && newTrxBalance.count > 0 && oldTrxBalance != newTrxBalance) ||
                    (oldUsdtBalance.count > 0 && newUsdtBalance.count > 0 && oldUsdtBalance != newUsdtBalance) {
                    model.updated = true
                    TRXMetricsDBManager.shared.upsertAssetSync(model: model)
                }
            }else{
                model.updated = true
                TRXMetricsDBManager.shared.upsertAssetSync(model: model)
            }
        }
    }
    
    
    func deletedBeforeTodayAssetsData(forChain chain: String) {
        let assets = TRXMetricsDBManager.shared.getAllAssetSyncModels(forChain: chain)
        if assets.count > 0 {
            TRXMetricsDBManager.shared.deleteAssetsBeforeToday(forChain: chain)
        }
    }
    
    
    public func makeCurrentAddressAssetSyncModel(trxBalance:String, usdtBalance:String, totalUsdBalance:String) -> TRXAssetSyncModel {
        let model = TRXAssetSyncModel()
        let address = dataConfig?.walletAddress ?? ""
        model.uId = TRXAddressMapManager.shared.id(for: address)
        model.idType = dataConfig?.uploadWalletType ?? 0
        model.trxBalance = trxBalance
        model.usdtBalance = usdtBalance
        model.usdBalance = totalUsdBalance
        model.date = Date().tronCore_getCurrentYMD_UTC()
        model.chain = dataConfig?.environmentKey ?? ""
        model.updated = true
        return model
    }
    
    
    //MARK: -Transaction
    func getCurrentChainUpdatedIsTrueAllTransactionSyncModels(forChain chain: String) -> [TRXTransactionSyncModel] {
        let transactions = TRXMetricsDBManager.shared.getUpdatedTransactionSyncModels(forChain: chain)
        return transactions
    }
    
    
    //Upload success, update database
    func callBackUpsertTransactionModel(model:TRXTransactionSyncModel) {
        model.updated = false
        TRXMetricsDBManager.shared.upsertTransactionSync(model: model)
    }
    
    
    //upsert database
    public func upsertTransactionsData(actionType:Int, tokenAddress:String, tokenAmount:String, energy:String,
                                bandwidth:String, burn:String) {
        guard let config = dataConfig, !isCollectionDisabled(config) else { return }
        let chain = config.environmentKey
        let address = config.walletAddress
        let uId = TRXAddressMapManager.shared.id(for: address)
        let date = Date().tronCore_getCurrentYMD_UTC()
        let m = TRXMetricsDBManager.shared.getTransactionSyncModel(chain: chain, uId: uId, actionType: actionType,
                                                                   tokenAddress: tokenAddress, date: date)
        if let tm = m {
            let totalCount = (tm.count ?? 0) + 1
            let totalTokenAmount = (tm.tokenAmount ?? "").tronCore_decimalNumberByAdding(numberString: tokenAmount).stringValue
            let totalEnergy = (tm.energy ?? "").tronCore_decimalNumberByAdding(numberString: energy).stringValue
            let totalBandwidth = (tm.bandwidth ?? "").tronCore_decimalNumberByAdding(numberString: bandwidth).stringValue
            let totalburn = (tm.burn ?? "").tronCore_decimalNumberByAdding(numberString: burn).stringValue
            let model = self.makeTransactionSyncModel(actionType: actionType,
                                                      count: totalCount,
                                                      tokenAddress: tokenAddress,
                                                      tokenAmount: tokenAmount,
                                                      totalTokenAmount: totalTokenAmount,
                                                      energy: totalEnergy,
                                                      bandwidth: totalBandwidth,
                                                      burn: totalburn,
                                                      updated: true,
                                                      localModel: tm,
                                                      config: config)
            TRXMetricsDBManager.shared.upsertTransactionSync(model: model)
        }else{
            let model = self.makeTransactionSyncModel(actionType: actionType,
                                                      count: 1,
                                                      tokenAddress: tokenAddress,
                                                      tokenAmount: tokenAmount,
                                                      totalTokenAmount: tokenAmount,
                                                      energy: energy,
                                                      bandwidth: bandwidth,
                                                      burn: burn,
                                                      updated: true,
                                                      localModel: TRXTransactionSyncModel(),
                                                      config: config)
            TRXMetricsDBManager.shared.upsertTransactionSync(model: model)
        }
        
    }
    
    
    
    func deletedBeforeTodayTransactionsData(forChain chain: String) {
        let transactions = TRXMetricsDBManager.shared.getAllTransactionSyncModels(forChain: chain)
        if transactions.count > 0 {
            TRXMetricsDBManager.shared.deleteTransactionSyncBeforeToday(forChain: chain)
        }
    }
    
    
    
    func makeTransactionSyncModel(actionType:Int, count:Int, tokenAddress:String, tokenAmount:String, totalTokenAmount:String,
                                  energy:String, bandwidth:String, burn:String, updated:Bool, localModel:TRXTransactionSyncModel,
                                  config:TRXMetricsDataSource) -> TRXTransactionSyncModel {
        var model = TRXTransactionSyncModel()
        model.uId = TRXAddressMapManager.shared.id(for: config.walletAddress)
        model.idType = config.uploadWalletType
        model.actionType = actionType
        model.count = count
        model.tokenAddress = tokenAddress
        model.tokenAmount = totalTokenAmount
        model.energy = energy
        model.bandwidth = bandwidth
        model.burn = burn
        model.date = Date().tronCore_getCurrentYMD_UTC()
        model.chain = config.environmentKey
        model.updated = updated
        if tokenAddress == "_" || tokenAddress == config.usdtContractAddress {
            let localHierarchyArr = Self.bucketKeyPaths.map { localModel[keyPath: $0] ?? 0 }
            let arr = self.distributionTokenAmount(forTokenAmount: tokenAmount, localHierarchyArr:localHierarchyArr)
            zip(Self.bucketKeyPaths, arr).forEach { keyPath, value in
                model[keyPath: keyPath] = value
            }
        }
        return model
    }
    
    
    func distributionTokenAmount(forTokenAmount tokenAmount: String, localHierarchyArr:Array<Int>) -> [Int] {
        var res = localHierarchyArr
        let amount = NSDecimalNumber(string: tokenAmount)
        // NSDecimalNumber(string:) returns notANumber for unparseable strings
        guard amount != .notANumber else { return res }
        let zero = NSDecimalNumber.zero
        // amount must be > 0
        guard amount.compare(zero) == .orderedDescending else { return res }
        for (threshold, idx) in Self.amountBuckets {
            if amount.compare(threshold) != .orderedDescending {
                res[idx] += 1
                return res
            }
        }
        res[8] += 1
        return res
    }

    
    //MARK: -upload
    public func uploadStatisticalData() {
        guard !isCollectionDisabled(dataConfig) else { return }
        // All DB operations run on the dedicated background queue to avoid blocking the main thread.
        // Migration is performed synchronously on this queue, so upload only starts after migration completes.
        metricsQueue.async { [weak self] in
            guard let self = self else { return }
            guard let config = self.dataConfig, !self.isCollectionDisabled(config) else { return }
            let chain = config.environmentKey
            let walletAddress = config.walletAddress
            TRXMetricsDBManager.shared.migrateFromLegacyIfNeeded(dataSource: config)
#if DEBUG
            self.uploadStatisticalDataToServer(config: config, chain: chain, walletAddress: walletAddress)
#else
            if config.isOnlineEnvironment || config.isPreReleaseEnvironment {
                self.uploadStatisticalDataToServer(config: config, chain: chain, walletAddress: walletAddress)
            }
#endif
        }
    }
    
    /// Must be called from metricsQueue.
    func uploadStatisticalDataToServer(config: TRXMetricsDataSource, chain: String, walletAddress: String) {
        guard isCurrentCollectionConfig(config, chain: chain, walletAddress: walletAddress) else { return }
        let assets = self.getCurrentChainUpdatedIsTrueAllAssetSyncModels(forChain: chain)
        let transactions = self.getCurrentChainUpdatedIsTrueAllTransactionSyncModels(forChain: chain)
        if assets.count > 0 || transactions.count > 0 {
            TRXStatisticalUploadViewModel().uploadStatisticalDatabase(assets: assets,
                                                                      transactions: transactions,
                                                                      dataConfig: config,
                                                                      chain: chain,
                                                                      walletAddress: walletAddress) { [weak self] isUploadSuccess, visible in
                guard let self = self else { return }
                // UserDefaults write is lightweight, safe on any thread.
                UserDefaults.standard.set(visible, forKey: Metrics_Statistical_Upload_Visible_Key)
                if isUploadSuccess {
                    // Post-upload DB writes go back to the dedicated queue.
                    self.metricsQueue.async {
                        self.deletedBeforeTodayAssetsData(forChain: chain)
                        let newAssets = self.getCurrentChainUpdatedIsTrueAllAssetSyncModels(forChain: chain)
                        for asset in newAssets {
                            self.upsertAssetData(model: asset, callBackUpdate: true)
                        }
                        self.deletedBeforeTodayTransactionsData(forChain: chain)
                        let newTransactions = self.getCurrentChainUpdatedIsTrueAllTransactionSyncModels(forChain: chain)
                        for ts in newTransactions {
                            self.callBackUpsertTransactionModel(model: ts)
                        }
                    }
                } else {
                    NSLog("[Metrics] server returned isUploadSuccess=false, will retry next cycle")
                }
            } failure: {
                NSLog("upload failure")
            }
        }
    }
    

    
    
    public func parameterProcessing(parameters: [String: Any], requestString: String, headers: [String: String]) throws -> [String: Any] {
        let hexCharacters = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
        let decimalCharacters = CharacterSet(charactersIn: "0123456789")
        guard let url = URL(string: requestString),
              let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let signature = comps.queryItems?.first(where: { $0.name.lowercased() == "signature" })?.value,
              signature.count == 40,
              signature.rangeOfCharacter(from: hexCharacters.inverted) == nil,
              let ts = headers["ts"],
              ts.count == 13,
              ts.rangeOfCharacter(from: decimalCharacters.inverted) == nil else {
            NSLog("[Metrics] skip request due to invalid encryption inputs")
            throw ParameterProcessingError.invalidEncryptionInputs
        }
        var newParams: [String: String] = [:]
        for (key, value) in parameters {
            let plain: String = {
                if let s = value as? String { return s }
                if JSONSerialization.isValidJSONObject(value) {
                    if let data = try? JSONSerialization.data(withJSONObject: value, options: []),
                       let json = String(data: data, encoding: .utf8) {
                        return json
                    }
                }
                return "\(value)"
            }()
            let encryptedP = TRXMetricsEncryptTool.encryptActionData(secretKey: signature, ts: ts, plaintext: plain)
            if encryptedP.isEmpty {
                NSLog("[Metrics] skip request due to AES encrypt failure: %@", key)
                throw ParameterProcessingError.encryptionFailed
            }
            newParams[key] = encryptedP
        }
        return newParams
    }
}
