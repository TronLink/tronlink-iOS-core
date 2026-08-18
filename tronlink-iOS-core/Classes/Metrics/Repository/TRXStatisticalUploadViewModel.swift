class TRXStatisticalUploadViewModel: NSObject {
    //MARK: -Upload
    func uploadStatisticalDatabase(assets:[TRXAssetSyncModel],
                               transactions:[TRXTransactionSyncModel],
                               dataConfig: TRXMetricsDataSource,
                               chain: String,
                               walletAddress: String,
                               success: @escaping (Bool,Bool) -> (),
                               failure: @escaping ()->()) {
        let x = self.buildAssetParameter(from: assets)
        var params: [String: Any] = ["X": x]
        if !transactions.isEmpty {
            params["Y"] = self.buildTransactionsParameter(from: transactions)
        }
        var visible = false
        if let v = UserDefaults.standard.object(forKey: Metrics_Statistical_Upload_Visible_Key) as? Bool {
            visible = v
        }
        
        guard TRXStatisticalUploadManager.shared.isCurrentCollectionConfig(dataConfig,
                                                                            chain: chain,
                                                                            walletAddress: walletAddress) else {
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
            fields.append(formatReportNumber(m.trxBalance))
            fields.append(formatReportNumber(m.usdtBalance))
            fields.append(formatReportNumber(m.usdBalance))
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

    fileprivate func formatReportNumber(_ value: String?) -> String {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              value.count > 0,
              value.count <= Self.reportNumberMaxLength,
              value.tronCore_isPureNumber() else {
            return "0"
        }
        let integerDigits = value.dropFirst(value.hasPrefix("-") ? 1 : 0).prefix { $0 != "." }.count
        guard integerDigits <= Self.reportNumberMaxIntegerDigits else { return "0" }
        let number = NSDecimalNumber(string: value)
        guard number != .notANumber else { return "0" }
        let precision = reportNumberPrecision(for: number)
        let quotient = number.dividing(by: precision)
        let floored = quotient.rounding(accordingToBehavior: Self.reportNumberFloorBehavior)
        return floored
            .multiplying(by: precision)
            .rounding(accordingToBehavior: Self.reportNumberDecimalBehavior)
            .stringValue
            .tronCore_removeFloatSuffixZero()
    }

    private static let reportNumberFloorBehavior = NSDecimalNumberHandler(roundingMode: .down,
                                                                          scale: 0,
                                                                          raiseOnExactness: false,
                                                                          raiseOnOverflow: false,
                                                                          raiseOnUnderflow: false,
                                                                          raiseOnDivideByZero: false)
    private static let reportNumberDecimalBehavior = NSDecimalNumberHandler(roundingMode: .down,
                                                                            scale: 1,
                                                                            raiseOnExactness: false,
                                                                            raiseOnOverflow: false,
                                                                            raiseOnUnderflow: false,
                                                                            raiseOnDivideByZero: false)
    private static let reportNumberMinPrecision = NSDecimalNumber(string: "0.1")
    private static let reportNumberBaseUpperBound = NSDecimalNumber(string: "100")
    private static let reportNumberTen = NSDecimalNumber(string: "10")
    // ponytail: conservative bound. NSDecimal tops out near 3.4e166 and reportNumberPrecision only
    // raises NSDecimalNumberOverflowException once upperBound reaches 1e167, so the real crash point
    // sits around 1e165. Raise this only if a report value legitimately needs more integer digits.
    private static let reportNumberMaxIntegerDigits = 127
    // Fraction digits never enter the precision loop, so the total length is capped only to keep
    // absurdly long strings out of the regex: sign + 127 integer digits + '.' + 128 fraction digits.
    private static let reportNumberMaxLength = 257

    fileprivate func reportNumberPrecision(for number: NSDecimalNumber) -> NSDecimalNumber {
        var upperBound = Self.reportNumberBaseUpperBound
        var precision = Self.reportNumberMinPrecision
        while number.compare(upperBound) != .orderedAscending {
            upperBound = upperBound.multiplying(by: Self.reportNumberTen)
            precision = precision.multiplying(by: Self.reportNumberTen)
        }
        return precision
    }
}
