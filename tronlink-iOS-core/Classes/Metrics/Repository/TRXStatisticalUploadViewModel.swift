class TRXStatisticalUploadViewModel: NSObject {
    //MARK: -Upload
    func uploadStatisticalDatabase(assets:[TRXAssetSyncModel],
                               transactions:[TRXTransactionSyncModel],
                               success: @escaping (Bool,Bool) -> (),
                               failure: @escaping ()->()) {
        let x = self.buildAssetParameter(from: assets)
        var params: [String: Any] = ["X": x]
        if transactions.count > 0 {
            let y = self.buildTransactionsParameter(from: transactions)
            params = ["X": x,"Y": y]
        }
        var visible = false
        if let v = UserDefaults.standard.object(forKey: Metrics_Statistical_Upload_Visible_Key) as? Bool {
            visible = v
        }
        
        guard let dataConfig = TRXStatisticalUploadManager.shared.dataConfig else {
            failure()
            return
        }
        
        dataConfig.uploadStatisticalData(parameters: params, visible: visible, success: { isUploadSuccess, isVisible in
            success(isUploadSuccess, isVisible)
        }, failure: {
            failure()
        })
    }
    
    //MARK: -Helpers
    func buildAssetParameter(from models: [TRXAssetSyncModel]) -> String {
        var parts: [String] = []
        for m in models {
            var fields: [String] = []
            fields.append("V1X")
            fields.append(fmt(m.uId))
            fields.append(fmtInt(m.idType))
            fields.append(fmt(m.trxBalance))
            fields.append(fmt(m.usdtBalance))
            fields.append(fmt(m.usdBalance))
            fields.append(fmt(m.date))
            
            let record = fields.joined(separator: "|") + "|"
            parts.append(record)
        }

        return parts.joined()
    }
    
    
    func buildTransactionsParameter(from models: [TRXTransactionSyncModel]) -> String {
        var parts: [String] = []
        
        for m in models {
            // "V1Y|uId|idType|actionType|count|tokenAddress|tokenAmount|energy|bandwidth|burn|date|A1:1,A2:3|"
            var recordFields: [String] = []
            
            recordFields.append("V1Y")
            recordFields.append(fmt(m.uId))
            recordFields.append(fmtInt(m.idType))
            recordFields.append(fmtInt(m.actionType))
            recordFields.append(fmtInt(m.count))
            recordFields.append(fmt(m.tokenAddress))
            recordFields.append(fmt(m.tokenAmount))
            recordFields.append(fmt(m.energy))
            recordFields.append(fmt(m.bandwidth))
            recordFields.append(fmt(m.burn))
            recordFields.append(fmt(m.date))
            
            // A1..A9
            var aParts: [String] = []
            if let v = m.A1, v > 0 { aParts.append("A1:\(v)") }
            if let v = m.A2, v > 0 { aParts.append("A2:\(v)") }
            if let v = m.A3, v > 0 { aParts.append("A3:\(v)") }
            if let v = m.A4, v > 0 { aParts.append("A4:\(v)") }
            if let v = m.A5, v > 0 { aParts.append("A5:\(v)") }
            if let v = m.A6, v > 0 { aParts.append("A6:\(v)") }
            if let v = m.A7, v > 0 { aParts.append("A7:\(v)") }
            if let v = m.A8, v > 0 { aParts.append("A8:\(v)") }
            if let v = m.A9, v > 0 { aParts.append("A9:\(v)") }
            
            let aField = aParts.joined(separator: ",")
            if aField.count > 0 {
                recordFields.append(aField)
            }
            
            let recordString = recordFields.joined(separator: "|") + "|"
            parts.append(recordString)
        }
        
        // concatenate all records (they already include trailing '|')
        let result = parts.joined()
        return result
    }
    
    
    fileprivate func fmt(_ s: String?) -> String {
        guard let s = s else { return "" }
        return s
    }
    
    
    fileprivate func fmtInt(_ v: Int?) -> String {
        guard let v = v else { return "" }
        return String(v)
    }
}
