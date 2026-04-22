import Foundation

let Metrics_Statistical_Upload_Visible_Key = "TRXStatisticalUploadVisibleKey"

public class TRXStatisticalUploadManager: NSObject {
    @objc public static let shared = TRXStatisticalUploadManager()
    
    /// Dedicated serial background queue for all DB and upload operations.
    private let metricsQueue = DispatchQueue(label: "com.tronlink.metrics", qos: .utility)
    
    private override init() {}
    
    //MARK: -Required parameters, passed when the app starts.
    public var dataConfig: TRXMetricsDataSource?
    
    
    //MARK: -assets
    func getCurrentChainUpdatedIsTrueAllAssetSyncModels() -> [TRXAssetSyncModel] {
        let chain = dataConfig?.environmentKey ?? ""
        let assets = TRXMetricsDBManager.shared.getUpdatedAssetSyncModels(forChain: chain)
        return assets
    }
    
    
    func upsertAssetDataCompareAndUpsert(model:TRXAssetSyncModel, callBackUpdate:Bool) {
        if (dataConfig?.isShastaEnvironment ?? false) || (dataConfig?.isWatchWallet ?? false) || (dataConfig?.isBasicFunctionOpen ?? false) || (dataConfig?.isTokenCloudSyncClose ?? false) {
            return
        }
        TRXMetricsDBManager.shared.upsertAssetSync_compareAndUpsert(model: model, callBackUpdate: callBackUpdate)
    }
    
    
    public func upsertAssetData(model:TRXAssetSyncModel, callBackUpdate:Bool=false) {
        if (dataConfig?.isShastaEnvironment ?? false) || (dataConfig?.isWatchWallet ?? false) || (dataConfig?.isBasicFunctionOpen ?? false) || (dataConfig?.isTokenCloudSyncClose ?? false) {
            return
        }
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
    
    
    func deletedBeforeTodayAssetsData() {
        let chain = dataConfig?.environmentKey ?? ""
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
    func getCurrentChainUpdatedIsTrueAllTransactionSyncModels() -> [TRXTransactionSyncModel] {
        let chain = dataConfig?.environmentKey ?? ""
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
        if (dataConfig?.isShastaEnvironment ?? false) || (dataConfig?.isWatchWallet ?? false) || (dataConfig?.isBasicFunctionOpen ?? false) {return}
        let chain = dataConfig?.environmentKey ?? ""
        let address = dataConfig?.walletAddress ?? ""
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
                                                      localModel: tm)
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
                                                      localModel: TRXTransactionSyncModel())
            TRXMetricsDBManager.shared.upsertTransactionSync(model: model)
        }
        
    }
    
    
    
    func deletedBeforeTodayTransactionsData() {
        let chain = dataConfig?.environmentKey ?? ""
        let transactions = TRXMetricsDBManager.shared.getAllTransactionSyncModels(forChain: chain)
        if transactions.count > 0 {
            TRXMetricsDBManager.shared.deleteTransactionSyncBeforeToday(forChain: chain)
        }
    }
    
    
    
    func makeTransactionSyncModel(actionType:Int, count:Int, tokenAddress:String, tokenAmount:String, totalTokenAmount:String,
                                  energy:String, bandwidth:String, burn:String, updated:Bool, localModel:TRXTransactionSyncModel) -> TRXTransactionSyncModel {
        let model = TRXTransactionSyncModel()
        let address = dataConfig?.walletAddress ?? ""
        model.uId = TRXAddressMapManager.shared.id(for: address)
        model.idType = dataConfig?.uploadWalletType ?? 0
        model.actionType = actionType
        model.count = count
        model.tokenAddress = tokenAddress
        model.tokenAmount = totalTokenAmount
        model.energy = energy
        model.bandwidth = bandwidth
        model.burn = burn
        model.date = Date().tronCore_getCurrentYMD_UTC()
        model.chain = dataConfig?.environmentKey ?? ""
        model.updated = updated
        if tokenAddress == "_" || tokenAddress == dataConfig?.usdtContractAddress {
            let localA1 = localModel.A1 ?? 0
            let localA2 = localModel.A2 ?? 0
            let localA3 = localModel.A3 ?? 0
            let localA4 = localModel.A4 ?? 0
            let localA5 = localModel.A5 ?? 0
            let localA6 = localModel.A6 ?? 0
            let localA7 = localModel.A7 ?? 0
            let localA8 = localModel.A8 ?? 0
            let localA9 = localModel.A9 ?? 0
            let localHierarchyArr = [localA1,localA2,localA3,localA4,localA5,localA6,localA7,localA8,localA9]
            let arr = self.distributionTokenAmount(forTokenAmount: tokenAmount, localHierarchyArr:localHierarchyArr)
            model.A1 = arr[0]
            model.A2 = arr[1]
            model.A3 = arr[2]
            model.A4 = arr[3]
            model.A5 = arr[4]
            model.A6 = arr[5]
            model.A7 = arr[6]
            model.A8 = arr[7]
            model.A9 = arr[8]
        }
        return model
    }
    
    
    func distributionTokenAmount(forTokenAmount tokenAmount: String, localHierarchyArr:Array<Int>) -> [Int] {
        var res = localHierarchyArr
        let amount = tokenAmount.tronCore_doubleValue
        if amount > 0 && amount <= 1 {
            res[0] += 1
        } else if amount > 1 && amount <= 10 {
            res[1] += 1
        } else if amount > 10 && amount <= 100 {
            res[2] += 1
        } else if amount > 100 && amount <= 1_000 {
            res[3] += 1
        } else if amount > 1_000 && amount <= 10_000 {
            res[4] += 1
        } else if amount > 10_000 && amount <= 100_000 {
            res[5] += 1
        } else if amount > 100_000 && amount <= 1_000_000 {
            res[6] += 1
        } else if amount > 1_000_000 && amount <= 10_000_000 {
            res[7] += 1
        } else if amount > 10_000_000 {
            res[8] += 1
        }
        return res
    }

    
    //MARK: -upload
    public func uploadStatisticalData() {
        if (dataConfig?.isBasicFunctionOpen ?? false) || (dataConfig?.isShastaEnvironment ?? false) || (dataConfig?.isTokenCloudSyncClose ?? false) {
            return
        }
        // All DB operations run on the dedicated background queue to avoid blocking the main thread.
        // Migration is performed synchronously on this queue, so upload only starts after migration completes.
        metricsQueue.async { [weak self] in
            guard let self = self else { return }
            if let config = self.dataConfig {
                TRXMetricsDBManager.shared.migrateFromLegacyIfNeeded(dataSource: config)
            }
#if DEBUG
            self.uploadStatisticalDataToServer()
#else
            if (self.dataConfig?.isOnlineEnvironment ?? false) || (self.dataConfig?.isPreReleaseEnvironment ?? false) {
                self.uploadStatisticalDataToServer()
            }
#endif
        }
    }
    
    /// Must be called from metricsQueue.
    func uploadStatisticalDataToServer() {
        let assets = self.getCurrentChainUpdatedIsTrueAllAssetSyncModels()
        let transactions = self.getCurrentChainUpdatedIsTrueAllTransactionSyncModels()
        if assets.count > 0 || transactions.count > 0 {
            TRXStatisticalUploadViewModel().uploadStatisticalDatabase(assets: assets, transactions: transactions) { [weak self] isUploadSuccess, visible in
                guard let self = self else { return }
                // UserDefaults write is lightweight, safe on any thread.
                UserDefaults.standard.set(visible, forKey: Metrics_Statistical_Upload_Visible_Key)
                if isUploadSuccess {
                    // Post-upload DB writes go back to the dedicated queue.
                    self.metricsQueue.async {
                        self.deletedBeforeTodayAssetsData()
                        let newAssets = self.getCurrentChainUpdatedIsTrueAllAssetSyncModels()
                        for asset in newAssets {
                            self.upsertAssetData(model: asset, callBackUpdate: true)
                        }
                        self.deletedBeforeTodayTransactionsData()
                        let newTransactions = self.getCurrentChainUpdatedIsTrueAllTransactionSyncModels()
                        for ts in newTransactions {
                            self.callBackUpsertTransactionModel(model: ts)
                        }
                    }
                } else {
                }
            } failure: {
            }
        }
    }
    

    
    
    public func parameterProcessing(parameters: [String: Any], requestString: String, headers: [String: String]) -> [String: Any] {
        var signature = ""
        if let url = URL(string: requestString),
           let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let value = comps.queryItems?.first(where: { $0.name.lowercased() == "signature" })?.value {
            signature = value
        }
        let ts = headers["ts"] ?? ""
        let sig = signature.removingPercentEncoding ?? signature
        let newParams: [String: String] = parameters.mapValues { value in
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
            let encryptedP = TRXMetricsEncryptTool.encryptActionData(secretKey: sig, ts: ts, plaintext: plain)
            return encryptedP
        }
        return newParams
    }
}
