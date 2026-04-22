
import Foundation


public class TRXAssetSyncModel: NSObject, Codable {
    public var uId: String?     // Encrypted account address
    public var idType: Int?     // Address type, watch wallet does not upload data
    public var trxBalance: String?
    public var usdtBalance: String?
    public var usdBalance: String?
    public var date: String?
    public var chain: String?
    public var updated: Bool?   // Flag to indicate if this model data has changes that need to be reported

    public override init() {
        super.init()
    }
}

/*
 tokenAmount segmentation information:
 A1=(0, 1]
 A2=(1, 10]
 A3=(10, 100]
 A4=(100, 1k]
 A5=(1k, 10k]
 A6=(10k, 100k]
 A7=(100k, 1m]
 A8=(1m, 10m]
 A9=(10m, +∞)
 */
public class TRXTransactionSyncModel: NSObject, Codable {
    public var uId: String?
    public var idType: Int?
    public var actionType: Int?
    public var count: Int?
    public var tokenAddress: String?
    public var tokenAmount: String?
    public var energy: String?
    public var bandwidth: String?
    public var burn: String?
    public var date: String?
    public var A1: Int?
    public var A2: Int?
    public var A3: Int?
    public var A4: Int?
    public var A5: Int?
    public var A6: Int?
    public var A7: Int?
    public var A8: Int?
    public var A9: Int?
    
    public var chain: String?
    public var updated: Bool?

    public override init() {
        super.init()
    }
}
