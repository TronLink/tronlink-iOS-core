import Foundation
import FMDB

@objcMembers
public class TRXMetricsDBManager: NSObject {
    
    public static let shared = TRXMetricsDBManager()
    
    private var dataBaseQueue: FMDatabaseQueue!
    
    private static let kMigrationDoneKeyPrefix = "TRXMetricsMigrationDone_"
    private static let kDBPathMigrationKey = "TRXMetricsDBPathMigrationDone"

    private override init() {
        super.init()

        guard let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            // Should never happen on a real iOS device; fall back to in-memory DB so the app keeps running
            dataBaseQueue = FMDatabaseQueue(path: ":memory:")
            createAddressMapTable()
            createAssetSyncTable()
            createTransactionSyncTable()
            return
        }

        try? FileManager.default.createDirectory(at: appSupportDir, withIntermediateDirectories: true)
        let dbURL = appSupportDir.appendingPathComponent("TronLinkMetrics.sqlite")

        // Migrate legacy DB from Documents to ApplicationSupport.
        // Uses a flag so failed attempts retry on next launch instead of being silently skipped.
        if !UserDefaults.standard.bool(forKey: TRXMetricsDBManager.kDBPathMigrationKey) {
            if let legacyURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
                .appendingPathComponent("TronLinkMetrics.sqlite"),
               FileManager.default.fileExists(atPath: legacyURL.path) {
                // Remove any empty/partial DB left by a previous failed attempt, then retry
                try? FileManager.default.removeItem(at: dbURL)
                do {
                    try FileManager.default.moveItem(at: legacyURL, to: dbURL)
                    UserDefaults.standard.set(true, forKey: TRXMetricsDBManager.kDBPathMigrationKey)
                } catch {
                    // Move failed; old file preserved in Documents; will retry next launch
                }
            } else {
                // New user or no legacy DB; mark done so this block is never entered again
                UserDefaults.standard.set(true, forKey: TRXMetricsDBManager.kDBPathMigrationKey)
            }
        }

        // Fall back to in-memory DB if the file-based queue fails (e.g. disk permission error)
        dataBaseQueue = FMDatabaseQueue(path: dbURL.path) ?? FMDatabaseQueue(path: ":memory:")
        // Set backup exclusion after FMDB creates the file, so the flag is applied on
        // first launch too (setResourceValue requires the file to already exist).
        try? (dbURL as NSURL).setResourceValue(true, forKey: .isExcludedFromBackupKey)

        createAddressMapTable()
        createAssetSyncTable()
        createTransactionSyncTable()
    }

    // MARK: - Legacy Data Migration

    /// Migrates data from the old database to the new one (one-time per chain).
    /// Only marks migration as complete and clears legacy data when every record is written successfully.
    /// If any write fails, migration is NOT marked done and will be retried on the next upload cycle.
    public func migrateFromLegacyIfNeeded(dataSource: TRXMetricsDataSource) {
        let chain = dataSource.environmentKey
        guard !chain.isEmpty else { return }

        let migrationKey = TRXMetricsDBManager.kMigrationDoneKeyPrefix + chain
        let hasMigrated = UserDefaults.standard.bool(forKey: migrationKey)
        guard !hasMigrated else { return }

        let legacyAssets = dataSource.legacyUpdatedAssetSyncModels(forChain: chain) ?? []
        let legacyTransactions = dataSource.legacyUpdatedTransactionSyncModels(forChain: chain) ?? []

        guard !legacyAssets.isEmpty || !legacyTransactions.isEmpty else {
            // No old data – mark done immediately.
            UserDefaults.standard.set(true, forKey: migrationKey)
            return
        }

        var allSucceeded = true

        // Migrate asset records and track each result.
        for model in legacyAssets {
            let ok = upsertAssetSync(model: model)
            if !ok { allSucceeded = false }
        }

        // Migrate transaction records and track each result.
        for model in legacyTransactions {
            let ok = upsertTransactionSync(model: model)
            if !ok { allSucceeded = false }
        }

        if allSucceeded {
            UserDefaults.standard.set(true, forKey: migrationKey)
        }
        // If not all succeeded: do NOT mark done – will retry next upload cycle.
    }
    
    // MARK: - ASSET SYNC TABLE CREATION
    public func createAssetSyncTable() {
        self.dataBaseQueue.inDatabase { db in
            do {
                if let rs = try? db.executeQuery("SELECT count(*) as count FROM sqlite_master WHERE type = 'table' and name = ?", values: ["AssetSyncTable"]) {
                    var tableExist = false
                    if rs.next() {
                        tableExist = rs.int(forColumn: "count") > 0
                    }
                    rs.close()
                    
                    if !tableExist {
                        let createSql = """
                        CREATE TABLE IF NOT EXISTS AssetSyncTable (
                            uuid INTEGER PRIMARY KEY AUTOINCREMENT,
                            uId TEXT,
                            idType INTEGER,
                            trxBalance TEXT,
                            usdtBalance TEXT,
                            usdBalance TEXT,
                            date TEXT,
                            chain TEXT,
                            updated INTEGER DEFAULT 0,
                            UNIQUE(chain, uId, date)
                        )
                        """
                        db.executeUpdate(createSql, withArgumentsIn: [])
                    }
                }
            }
        }
    }
    
    // MARK: - ASSET SYNC TABLE METHODS
    private func insertAssetSyncTable_internal(db: FMDatabase, model: TRXAssetSyncModel) -> Bool {
        let uId = model.uId ?? ""
        let idTypeArg: Any = model.idType != nil ? model.idType! : NSNull()
        let trxBalance = model.trxBalance ?? ""
        let usdtBalance = model.usdtBalance ?? ""
        let usdBalance = model.usdBalance ?? ""
        let date = model.date ?? ""
        let chain = model.chain ?? ""
        let updatedInt: Int = (model.updated ?? false) ? 1 : 0
        return db.executeUpdate(
            "INSERT INTO AssetSyncTable (uId, idType, trxBalance, usdtBalance, usdBalance, date, chain, updated) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            withArgumentsIn: [uId, idTypeArg, trxBalance, usdtBalance, usdBalance, date, chain, updatedInt]
        )
    }

    private func updateAssetSync_internal(db: FMDatabase, chain: String, uId: String, idType:Int, date: String, trxBalance: String?, usdtBalance: String?, usdBalance: String?, updated: Bool?) -> Bool {
        if trxBalance == nil && usdtBalance == nil && usdBalance == nil && updated == nil {
            return false
        }
        var sqlParts: [String] = []
        var args: [Any] = []
        sqlParts.append("idType = ?")
        args.append(idType)
        if let trx = trxBalance { sqlParts.append("trxBalance = ?"); args.append(trx) }
        if let usdt = usdtBalance { sqlParts.append("usdtBalance = ?"); args.append(usdt) }
        if let usd = usdBalance { sqlParts.append("usdBalance = ?"); args.append(usd) }
        if let up = updated { sqlParts.append("updated = ?"); args.append(up ? 1 : 0) }

        args.append(chain)
        args.append(uId)
        args.append(date)

        let setClause = sqlParts.joined(separator: ", ")
        let sql = "UPDATE AssetSyncTable SET \(setClause) WHERE chain = ? AND uId = ? AND date = ?"
        return db.executeUpdate(sql, withArgumentsIn: args)
    }

    public func deleteAssetsBeforeToday(forChain chain: String) {
        let today = Date().tronCore_getCurrentYMD_UTC()
        self.dataBaseQueue.inDatabase { db in
            let sql = "DELETE FROM AssetSyncTable WHERE chain = ? AND date < ?"
            db.executeUpdate(sql, withArgumentsIn: [chain, today])
        }
    }
    
    public func getUpdatedAssetSyncModels(forChain chain: String) -> [TRXAssetSyncModel] {
        var results = [TRXAssetSyncModel]()
        self.dataBaseQueue.inDatabase { db in
            let sql = "SELECT uId, idType, trxBalance, usdtBalance, usdBalance, date, chain, updated FROM AssetSyncTable WHERE chain = ? AND updated = 1"
            if let rs = try? db.executeQuery(sql, values: [chain]) {
                while rs.next() {
                    let m = TRXAssetSyncModel()
                    m.uId = rs.string(forColumn: "uId")
                    if let num = rs.object(forColumn: "idType") as? NSNumber { m.idType = num.intValue } else { m.idType = nil }
                    m.trxBalance = rs.string(forColumn: "trxBalance")
                    m.usdtBalance = rs.string(forColumn: "usdtBalance")
                    m.usdBalance = rs.string(forColumn: "usdBalance")
                    m.date = rs.string(forColumn: "date")
                    m.chain = rs.string(forColumn: "chain")
                    let updatedVal = rs.int(forColumn: "updated")
                    m.updated = (updatedVal != 0)
                    results.append(m)
                }
                rs.close()
            }
        }
        return results
    }

    public func getAssetSyncModel(chain: String, uId: String, date: String) -> TRXAssetSyncModel? {
        var model: TRXAssetSyncModel? = nil
        self.dataBaseQueue.inDatabase { db in
            let sql = "SELECT uId, idType, trxBalance, usdtBalance, usdBalance, date, chain, updated FROM AssetSyncTable WHERE chain = ? AND uId = ? AND date = ? LIMIT 1"
            if let rs = try? db.executeQuery(sql, values: [chain, uId, date]) {
                if rs.next() {
                    let m = TRXAssetSyncModel()
                    m.uId = rs.string(forColumn: "uId")
                    if let num = rs.object(forColumn: "idType") as? NSNumber { m.idType = num.intValue } else { m.idType = nil }
                    m.trxBalance = rs.string(forColumn: "trxBalance")
                    m.usdtBalance = rs.string(forColumn: "usdtBalance")
                    m.usdBalance = rs.string(forColumn: "usdBalance")
                    m.date = rs.string(forColumn: "date")
                    m.chain = rs.string(forColumn: "chain")
                    let updatedVal = rs.int(forColumn: "updated")
                    m.updated = (updatedVal != 0)
                    model = m
                }
                rs.close()
            }
        }
        return model
    }

    public func upsertAssetSync_compareAndUpsert(model: TRXAssetSyncModel, callBackUpdate: Bool) {
        let chain = model.chain ?? ""
        let uId = model.uId ?? ""
        let date = model.date ?? ""
        let idType = model.idType ?? 0

        self.dataBaseQueue.inDatabase { db in
            db.beginTransaction()
            var success = false
            do {
                if callBackUpdate {
                    let m = model
                    m.updated = false
                    let checkSql = "SELECT COUNT(1) AS cnt FROM AssetSyncTable WHERE chain = ? AND uId = ? AND date = ?"
                    let rs = try db.executeQuery(checkSql, values: [chain, uId, date])
                    var exists = false
                    if rs.next() { exists = rs.int(forColumn: "cnt") > 0 }
                    rs.close()

                    if exists {
                        success = self.updateAssetSync_internal(db: db, chain: chain, uId: uId, idType: idType, date: date, trxBalance: m.trxBalance, usdtBalance: m.usdtBalance, usdBalance: m.usdBalance, updated: m.updated)
                    }
                } else {
                    let sql = "SELECT trxBalance, usdtBalance FROM AssetSyncTable WHERE chain = ? AND uId = ? AND date = ? LIMIT 1"
                    let rs = try db.executeQuery(sql, values: [chain, uId, date])
                    if rs.next() {
                        let oldTrx = rs.string(forColumn: "trxBalance") ?? ""
                        let oldUsdt = rs.string(forColumn: "usdtBalance") ?? ""
                        rs.close()

                        let oldTrxClean = oldTrx.tronCore_removeFloatSuffixZero()
                        let oldUsdtClean = oldUsdt.tronCore_removeFloatSuffixZero()
                        let newTrxClean = (model.trxBalance ?? "").tronCore_removeFloatSuffixZero()
                        let newUsdtClean = (model.usdtBalance ?? "").tronCore_removeFloatSuffixZero()

                        let m = model
                        if (oldTrxClean.count > 0 && newTrxClean.count > 0 && oldTrxClean != newTrxClean) ||
                            (oldUsdtClean.count > 0 && newUsdtClean.count > 0 && oldUsdtClean != newUsdtClean) {
                            m.updated = true
                            success = self.updateAssetSync_internal(db: db, chain: chain, uId: uId, idType: idType, date: date, trxBalance: m.trxBalance, usdtBalance: m.usdtBalance, usdBalance: m.usdBalance, updated: m.updated)
                        }
                    } else {
                        rs.close()
                        let m = model
                        m.updated = true
                        success = self.insertAssetSyncTable_internal(db: db, model: m)
                    }
                }

                if success { db.commit() } else { db.rollback() }
            } catch {
                db.rollback()
            }
        }
    }
    
    @discardableResult
    public func upsertAssetSync(model: TRXAssetSyncModel) -> Bool {
        let uId = model.uId ?? ""
        let chain = model.chain ?? ""
        let date = model.date ?? ""
        let idType = model.idType ?? 0
        var result = false

        self.dataBaseQueue.inDatabase { db in
            db.beginTransaction()
            do {
                let checkSql = "SELECT COUNT(1) AS cnt FROM AssetSyncTable WHERE chain = ? AND uId = ? AND date = ?"
                let rs = try db.executeQuery(checkSql, values: [chain, uId, date])
                var exists = false
                if rs.next() { exists = rs.int(forColumn: "cnt") > 0 }
                rs.close()

                if exists {
                    let ok = self.updateAssetSync_internal(db: db,
                                                           chain: chain,
                                                           uId: uId,
                                                           idType: idType,
                                                           date: date,
                                                           trxBalance: model.trxBalance,
                                                           usdtBalance: model.usdtBalance,
                                                           usdBalance: model.usdBalance,
                                                           updated: model.updated)
                    if ok { db.commit(); result = true } else { db.rollback() }
                } else {
                    let ok = self.insertAssetSyncTable_internal(db: db, model: model)
                    if ok { db.commit(); result = true } else { db.rollback() }
                }
            } catch {
                db.rollback()
            }
        }
        return result
    }
    
    public func getAllAssetSyncModels(forChain chain: String) -> [TRXAssetSyncModel] {
        var results = [TRXAssetSyncModel]()
        self.dataBaseQueue.inDatabase { db in
            let sql = "SELECT uId, idType, trxBalance, usdtBalance, usdBalance, date, chain, updated FROM AssetSyncTable WHERE chain = ?"
            if let rs = try? db.executeQuery(sql, values: [chain]) {
                while rs.next() {
                    let m = TRXAssetSyncModel()
                    m.uId = rs.string(forColumn: "uId")
                    if let num = rs.object(forColumn: "idType") as? NSNumber { m.idType = num.intValue } else { m.idType = nil }
                    m.trxBalance = rs.string(forColumn: "trxBalance")
                    m.usdtBalance = rs.string(forColumn: "usdtBalance")
                    m.usdBalance = rs.string(forColumn: "usdBalance")
                    m.date = rs.string(forColumn: "date")
                    m.chain = rs.string(forColumn: "chain")
                    let updatedVal = rs.int(forColumn: "updated")
                    m.updated = (updatedVal != 0)
                    results.append(m)
                }
                rs.close()
            }
        }
        return results
    }
    
    // MARK: - TRANSACTION SYNC TABLE CREATION
    public func createTransactionSyncTable() {
        self.dataBaseQueue.inDatabase { db in
            do {
                if let rs = try? db.executeQuery("SELECT count(*) as count FROM sqlite_master WHERE type = 'table' and name = ?", values: ["TransactionSyncTable"]) {
                    var tableExist = false
                    if rs.next() {
                        tableExist = rs.int(forColumn: "count") > 0
                    }
                    rs.close()
                    
                    if !tableExist {
                        let createSql = """
                        CREATE TABLE IF NOT EXISTS TransactionSyncTable (
                            uuid INTEGER PRIMARY KEY AUTOINCREMENT,
                            uId TEXT,
                            idType INTEGER,
                            actionType INTEGER,
                            count INTEGER,
                            tokenAddress TEXT,
                            tokenAmount TEXT,
                            energy TEXT,
                            bandwidth TEXT,
                            burn TEXT,
                            date TEXT,
                            chain TEXT,
                            updated INTEGER DEFAULT 0,
                            A1 INTEGER DEFAULT 0,
                            A2 INTEGER DEFAULT 0,
                            A3 INTEGER DEFAULT 0,
                            A4 INTEGER DEFAULT 0,
                            A5 INTEGER DEFAULT 0,
                            A6 INTEGER DEFAULT 0,
                            A7 INTEGER DEFAULT 0,
                            A8 INTEGER DEFAULT 0,
                            A9 INTEGER DEFAULT 0,
                            UNIQUE(chain, uId, actionType, tokenAddress, date)
                        )
                        """
                        db.executeUpdate(createSql, withArgumentsIn: [])
                    }
                }
            }
        }
    }
    
    // MARK: - TRANSACTION SYNC TABLE METHODS
    private func insertTransactionSync_internal(db: FMDatabase, model: TRXTransactionSyncModel) -> Bool {
        let uId = model.uId ?? ""
        let idTypeArg: Any = model.idType != nil ? model.idType! : NSNull()
        let actionTypeArg: Any = model.actionType != nil ? model.actionType! : NSNull()
        let countArg: Any = model.count != nil ? model.count! : NSNull()
        let tokenAddress = model.tokenAddress ?? ""
        let tokenAmount = model.tokenAmount ?? ""
        let energy = model.energy ?? ""
        let bandwidth = model.bandwidth ?? ""
        let burn = model.burn ?? ""
        let date = model.date ?? ""
        let chain = model.chain ?? ""
        let updatedArg: Any = (model.updated ?? false) ? 1 : 0

        let A1Arg: Any = model.A1 != nil ? model.A1! : 0
        let A2Arg: Any = model.A2 != nil ? model.A2! : 0
        let A3Arg: Any = model.A3 != nil ? model.A3! : 0
        let A4Arg: Any = model.A4 != nil ? model.A4! : 0
        let A5Arg: Any = model.A5 != nil ? model.A5! : 0
        let A6Arg: Any = model.A6 != nil ? model.A6! : 0
        let A7Arg: Any = model.A7 != nil ? model.A7! : 0
        let A8Arg: Any = model.A8 != nil ? model.A8! : 0
        let A9Arg: Any = model.A9 != nil ? model.A9! : 0

        return db.executeUpdate(
            "INSERT INTO TransactionSyncTable (uId, idType, actionType, count, tokenAddress, tokenAmount, energy, bandwidth, burn, date, chain, updated, A1, A2, A3, A4, A5, A6, A7, A8, A9) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            withArgumentsIn: [uId, idTypeArg, actionTypeArg, countArg, tokenAddress, tokenAmount, energy, bandwidth, burn, date, chain, updatedArg, A1Arg, A2Arg, A3Arg, A4Arg, A5Arg, A6Arg, A7Arg, A8Arg, A9Arg]
        )
    }

    private func updateTransactionSync_internal(db: FMDatabase, chain: String, uId: String, actionType: Int, tokenAddress: String, date: String, idType: Int?, count: Int?, tokenAmount: String?, energy: String?, bandwidth: String?, burn: String?, updated: Bool?, A1: Int?, A2: Int?, A3: Int?, A4: Int?, A5: Int?, A6: Int?, A7: Int?, A8: Int?, A9: Int?) -> Bool {
        var sqlParts: [String] = []
        var args: [Any] = []

        if let idType = idType { sqlParts.append("idType = ?"); args.append(idType) }
        if let count = count { sqlParts.append("count = ?"); args.append(count) }
        if let tokenAmount = tokenAmount { sqlParts.append("tokenAmount = ?"); args.append(tokenAmount) }
        if let energy = energy { sqlParts.append("energy = ?"); args.append(energy) }
        if let bandwidth = bandwidth { sqlParts.append("bandwidth = ?"); args.append(bandwidth) }
        if let burn = burn { sqlParts.append("burn = ?"); args.append(burn) }
        if let up = updated { sqlParts.append("updated = ?"); args.append(up ? 1 : 0) }

        if let v = A1 { sqlParts.append("A1 = ?"); args.append(v) }
        if let v = A2 { sqlParts.append("A2 = ?"); args.append(v) }
        if let v = A3 { sqlParts.append("A3 = ?"); args.append(v) }
        if let v = A4 { sqlParts.append("A4 = ?"); args.append(v) }
        if let v = A5 { sqlParts.append("A5 = ?"); args.append(v) }
        if let v = A6 { sqlParts.append("A6 = ?"); args.append(v) }
        if let v = A7 { sqlParts.append("A7 = ?"); args.append(v) }
        if let v = A8 { sqlParts.append("A8 = ?"); args.append(v) }
        if let v = A9 { sqlParts.append("A9 = ?"); args.append(v) }

        if sqlParts.isEmpty { return false }

        args.append(chain)
        args.append(uId)
        args.append(actionType)
        args.append(tokenAddress)
        args.append(date)

        let setClause = sqlParts.joined(separator: ", ")
        let sql = "UPDATE TransactionSyncTable SET \(setClause) WHERE chain = ? AND uId = ? AND actionType = ? AND tokenAddress = ? AND date = ?"
        return db.executeUpdate(sql, withArgumentsIn: args)
    }

    public func deleteTransactionSyncBeforeToday(forChain chain: String) {
        let today = Date().tronCore_getCurrentYMD_UTC()
        self.dataBaseQueue.inDatabase { db in
            let sql = "DELETE FROM TransactionSyncTable WHERE chain = ? AND date < ?"
            db.executeUpdate(sql, withArgumentsIn: [chain, today])
        }
    }

    public func getUpdatedTransactionSyncModels(forChain chain: String) -> [TRXTransactionSyncModel] {
        var results = [TRXTransactionSyncModel]()
        self.dataBaseQueue.inDatabase { db in
            let sql = "SELECT uId, idType, actionType, count, tokenAddress, tokenAmount, energy, bandwidth, burn, date, chain, updated, A1, A2, A3, A4, A5, A6, A7, A8, A9 FROM TransactionSyncTable WHERE chain = ? AND updated = 1"
            if let rs = try? db.executeQuery(sql, values: [chain]) {
                while rs.next() {
                    let m = TRXTransactionSyncModel()
                    m.uId = rs.string(forColumn: "uId")
                    if let num = rs.object(forColumn: "idType") as? NSNumber { m.idType = num.intValue } else { m.idType = nil }
                    if let num = rs.object(forColumn: "actionType") as? NSNumber { m.actionType = num.intValue } else { m.actionType = nil }
                    if let num = rs.object(forColumn: "count") as? NSNumber { m.count = num.intValue } else { m.count = nil }
                    m.tokenAddress = rs.string(forColumn: "tokenAddress")
                    m.tokenAmount = rs.string(forColumn: "tokenAmount")
                    m.energy = rs.string(forColumn: "energy")
                    m.bandwidth = rs.string(forColumn: "bandwidth")
                    m.burn = rs.string(forColumn: "burn")
                    m.date = rs.string(forColumn: "date")
                    m.chain = rs.string(forColumn: "chain")
                    if let num = rs.object(forColumn: "updated") as? NSNumber { m.updated = num.intValue == 1 } else { m.updated = false }
                    if let num = rs.object(forColumn: "A1") as? NSNumber { m.A1 = num.intValue } else { m.A1 = 0 }
                    if let num = rs.object(forColumn: "A2") as? NSNumber { m.A2 = num.intValue } else { m.A2 = 0 }
                    if let num = rs.object(forColumn: "A3") as? NSNumber { m.A3 = num.intValue } else { m.A3 = 0 }
                    if let num = rs.object(forColumn: "A4") as? NSNumber { m.A4 = num.intValue } else { m.A4 = 0 }
                    if let num = rs.object(forColumn: "A5") as? NSNumber { m.A5 = num.intValue } else { m.A5 = 0 }
                    if let num = rs.object(forColumn: "A6") as? NSNumber { m.A6 = num.intValue } else { m.A6 = 0 }
                    if let num = rs.object(forColumn: "A7") as? NSNumber { m.A7 = num.intValue } else { m.A7 = 0 }
                    if let num = rs.object(forColumn: "A8") as? NSNumber { m.A8 = num.intValue } else { m.A8 = 0 }
                    if let num = rs.object(forColumn: "A9") as? NSNumber { m.A9 = num.intValue } else { m.A9 = 0 }
                    results.append(m)
                }
                rs.close()
            }
        }
        return results
    }

    public func getAllTransactionSyncModels(forChain chain: String) -> [TRXTransactionSyncModel] {
        var results = [TRXTransactionSyncModel]()
        self.dataBaseQueue.inDatabase { db in
            let sql = "SELECT uId, idType, actionType, count, tokenAddress, tokenAmount, energy, bandwidth, burn, date, chain, updated, A1, A2, A3, A4, A5, A6, A7, A8, A9 FROM TransactionSyncTable WHERE chain = ?"
            if let rs = try? db.executeQuery(sql, values: [chain]) {
                while rs.next() {
                    let m = TRXTransactionSyncModel()
                    m.uId = rs.string(forColumn: "uId")
                    if let num = rs.object(forColumn: "idType") as? NSNumber { m.idType = num.intValue } else { m.idType = nil }
                    if let num = rs.object(forColumn: "actionType") as? NSNumber { m.actionType = num.intValue } else { m.actionType = nil }
                    if let num = rs.object(forColumn: "count") as? NSNumber { m.count = num.intValue } else { m.count = nil }
                    m.tokenAddress = rs.string(forColumn: "tokenAddress")
                    m.tokenAmount = rs.string(forColumn: "tokenAmount")
                    m.energy = rs.string(forColumn: "energy")
                    m.bandwidth = rs.string(forColumn: "bandwidth")
                    m.burn = rs.string(forColumn: "burn")
                    m.date = rs.string(forColumn: "date")
                    m.chain = rs.string(forColumn: "chain")
                    if let num = rs.object(forColumn: "updated") as? NSNumber { m.updated = num.intValue == 1 } else { m.updated = false }
                    if let num = rs.object(forColumn: "A1") as? NSNumber { m.A1 = num.intValue } else { m.A1 = 0 }
                    if let num = rs.object(forColumn: "A2") as? NSNumber { m.A2 = num.intValue } else { m.A2 = 0 }
                    if let num = rs.object(forColumn: "A3") as? NSNumber { m.A3 = num.intValue } else { m.A3 = 0 }
                    if let num = rs.object(forColumn: "A4") as? NSNumber { m.A4 = num.intValue } else { m.A4 = 0 }
                    if let num = rs.object(forColumn: "A5") as? NSNumber { m.A5 = num.intValue } else { m.A5 = 0 }
                    if let num = rs.object(forColumn: "A6") as? NSNumber { m.A6 = num.intValue } else { m.A6 = 0 }
                    if let num = rs.object(forColumn: "A7") as? NSNumber { m.A7 = num.intValue } else { m.A7 = 0 }
                    if let num = rs.object(forColumn: "A8") as? NSNumber { m.A8 = num.intValue } else { m.A8 = 0 }
                    if let num = rs.object(forColumn: "A9") as? NSNumber { m.A9 = num.intValue } else { m.A9 = 0 }
                    results.append(m)
                }
                rs.close()
            }
        }
        return results
    }

    public func getTransactionSyncModel(chain: String, uId: String, actionType: Int, tokenAddress: String, date: String) -> TRXTransactionSyncModel? {
        var result: TRXTransactionSyncModel? = nil
        self.dataBaseQueue.inDatabase { db in
            let sql = "SELECT uId, idType, actionType, count, tokenAddress, tokenAmount, energy, bandwidth, burn, date, chain, updated, A1, A2, A3, A4, A5, A6, A7, A8, A9 FROM TransactionSyncTable WHERE chain = ? AND uId = ? AND actionType = ? AND tokenAddress = ? AND date = ? LIMIT 1"
            if let rs = try? db.executeQuery(sql, values: [chain, uId, actionType, tokenAddress, date]) {
                if rs.next() {
                    let m = TRXTransactionSyncModel()
                    m.uId = rs.string(forColumn: "uId")
                    if let num = rs.object(forColumn: "idType") as? NSNumber { m.idType = num.intValue } else { m.idType = nil }
                    if let num = rs.object(forColumn: "actionType") as? NSNumber { m.actionType = num.intValue } else { m.actionType = nil }
                    if let num = rs.object(forColumn: "count") as? NSNumber { m.count = num.intValue } else { m.count = nil }
                    m.tokenAddress = rs.string(forColumn: "tokenAddress")
                    m.tokenAmount = rs.string(forColumn: "tokenAmount")
                    m.energy = rs.string(forColumn: "energy")
                    m.bandwidth = rs.string(forColumn: "bandwidth")
                    m.burn = rs.string(forColumn: "burn")
                    m.date = rs.string(forColumn: "date")
                    m.chain = rs.string(forColumn: "chain")
                    if let num = rs.object(forColumn: "updated") as? NSNumber { m.updated = num.intValue == 1 } else { m.updated = false }
                    if let num = rs.object(forColumn: "A1") as? NSNumber { m.A1 = num.intValue } else { m.A1 = 0 }
                    if let num = rs.object(forColumn: "A2") as? NSNumber { m.A2 = num.intValue } else { m.A2 = 0 }
                    if let num = rs.object(forColumn: "A3") as? NSNumber { m.A3 = num.intValue } else { m.A3 = 0 }
                    if let num = rs.object(forColumn: "A4") as? NSNumber { m.A4 = num.intValue } else { m.A4 = 0 }
                    if let num = rs.object(forColumn: "A5") as? NSNumber { m.A5 = num.intValue } else { m.A5 = 0 }
                    if let num = rs.object(forColumn: "A6") as? NSNumber { m.A6 = num.intValue } else { m.A6 = 0 }
                    if let num = rs.object(forColumn: "A7") as? NSNumber { m.A7 = num.intValue } else { m.A7 = 0 }
                    if let num = rs.object(forColumn: "A8") as? NSNumber { m.A8 = num.intValue } else { m.A8 = 0 }
                    if let num = rs.object(forColumn: "A9") as? NSNumber { m.A9 = num.intValue } else { m.A9 = 0 }
                    result = m
                }
                rs.close()
            }
        }
        return result
    }

    // MARK: - ADDRESS MAP TABLE

    public func createAddressMapTable() {
        dataBaseQueue.inDatabase { db in
            let sql = """
            CREATE TABLE IF NOT EXISTS AddressMapTable (
                address TEXT PRIMARY KEY,
                uuid TEXT NOT NULL
            )
            """
            db.executeUpdate(sql, withArgumentsIn: [])
        }
    }

    /// Replaces all address→uuid mappings atomically. Returns true on success.
    @discardableResult
    public func saveAddressMappings(_ mapping: [String: String]) -> Bool {
        var result = false
        dataBaseQueue.inDatabase { db in
            db.beginTransaction()
            guard db.executeUpdate("DELETE FROM AddressMapTable", withArgumentsIn: []) else {
                db.rollback()
                return
            }
            var allInserted = true
            for (address, uuid) in mapping {
                if !db.executeUpdate(
                    "INSERT INTO AddressMapTable (address, uuid) VALUES (?, ?)",
                    withArgumentsIn: [address, uuid]
                ) {
                    allInserted = false
                    break
                }
            }
            if allInserted {
                db.commit()
                result = true
            } else {
                db.rollback()
            }
        }
        return result
    }

    public func loadAllAddressMappings() -> [String: String] {
        var result: [String: String] = [:]
        dataBaseQueue.inDatabase { db in
            if let rs = try? db.executeQuery("SELECT address, uuid FROM AddressMapTable", values: nil) {
                while rs.next() {
                    if let addr = rs.string(forColumn: "address"),
                       let uuid = rs.string(forColumn: "uuid") {
                        result[addr] = uuid
                    }
                }
                rs.close()
            }
        }
        return result
    }

    // MARK: -

    @discardableResult
    public func upsertTransactionSync(model: TRXTransactionSyncModel) -> Bool {
        let uId = model.uId ?? ""
        let chain = model.chain ?? ""
        let actionTypeVal = model.actionType ?? -1
        let tokenAddressVal = model.tokenAddress ?? ""
        let dateVal = model.date ?? ""

        var result = false
        self.dataBaseQueue.inDatabase { db in
            db.beginTransaction()
            do {
                let checkSql = "SELECT COUNT(1) AS cnt FROM TransactionSyncTable WHERE chain = ? AND uId = ? AND actionType = ? AND tokenAddress = ? AND date = ?"
                let rs = try db.executeQuery(checkSql, values: [chain, uId, actionTypeVal, tokenAddressVal, dateVal])
                var exists = false
                if rs.next() { exists = rs.int(forColumn: "cnt") > 0 }
                rs.close()

                if exists {
                    let ok = self.updateTransactionSync_internal(db: db, chain: chain, uId: uId, actionType: actionTypeVal, tokenAddress: tokenAddressVal, date: dateVal, idType: model.idType, count: model.count, tokenAmount: model.tokenAmount, energy: model.energy, bandwidth: model.bandwidth, burn: model.burn, updated: model.updated, A1: model.A1, A2: model.A2, A3: model.A3, A4: model.A4, A5: model.A5, A6: model.A6, A7: model.A7, A8: model.A8, A9: model.A9)
                    if ok { db.commit(); result = true } else { db.rollback(); result = false }
                } else {
                    let ok = self.insertTransactionSync_internal(db: db, model: model)
                    if ok { db.commit(); result = true } else { db.rollback(); result = false }
                }
            } catch {
                db.rollback()
                result = false
            }
        }
        return result
    }
}
