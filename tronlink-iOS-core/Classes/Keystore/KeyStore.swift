
import Foundation
import Darwin

/// Manages directories of key and wallet files and presents them as accounts.
public final class KeyStore {
    /// The key file directory.
    public let keyDirectory: URL

    /// Each account retains the digest of the encrypted file it loaded or last saved.
    /// Staging a replacement with addKey leaves that digest intact.
    private var accountsByAddress = [Address: (account: Account, fileDigest: Data)]()

    /// Dictionary of keys by address.
    private var keysByAddress = [Address: KeystoreKey]()

    /// Retry unavailable protected files without treating them as invalid JSON.
    private var pendingAccountURLs = [URL]()
    private var loadedAccountURLs = Set<URL>()
    /// The directory could not be created or listed, so the set of key files is unknown.
    private var directoryListingPending = false
    /// While true, `save` and `delete` throw `CocoaError(.fileReadUnknown)`: storage is
    /// temporarily unavailable (for example, the device is locked), not invalid input.
    private var hasUnreadableAccounts: Bool {
        return directoryListingPending || pendingAccountURLs.contains { !loadedAccountURLs.contains($0) }
    }
    private var backupExclusionPending = true

    /// Mutations always acquire this lock before `stateLock`; reads only acquire `stateLock`.
    private let mutationLock = NSLock()
    private let stateLock = NSLock()

    /// Creates a `KeyStore` for the given directory.
    ///
    /// A directory that cannot be created or listed yet is retried on later access instead
    /// of failing initialization; until then no accounts are listed and writes are refused.
    public init(keyDirectory: URL) throws {
        self.keyDirectory = keyDirectory
        load()
    }

    private func load() {
        let fileManager = FileManager.default
        let accountURLs: [URL]
        do {
            try fileManager.createDirectory(at: keyDirectory, withIntermediateDirectories: true, attributes: nil)
            retryDirectoryBackupExclusion()
            accountURLs = try fileManager.contentsOfDirectory(at: keyDirectory, includingPropertiesForKeys: [], options: [.skipsHiddenFiles])
        } catch {
            directoryListingPending = true
            return
        }
        directoryListingPending = false
        loadAccounts(at: accountURLs)
    }

    private func loadAccounts(at urls: [URL]) {
        pendingAccountURLs.removeAll(keepingCapacity: true)
        for url in urls {
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
                continue
            }
            let json: Data
            do {
                json = try Data(contentsOf: url)
            } catch {
                if (error as? CocoaError)?.code != .fileReadNoSuchFile {
                    pendingAccountURLs.append(url)
                }
                continue
            }
            guard let key = try? JSONDecoder().decode(KeystoreKey.self, from: json) else {
                continue
            }
            do {
                try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
                try excludeFromBackup(at: url)
            } catch {
                pendingAccountURLs.append(url)
            }
            // Metadata retries must not re-register a file after its account was deleted.
            guard loadedAccountURLs.insert(url).inserted else { continue }
            // A metadata failure must not hide a valid account or permit a duplicate import.
            // A retry must not replace a key installed by addKey before addAccount saves it.
            if keysByAddress[key.address] == nil {
                cache(key)
            }
            if accountsByAddress[key.address] == nil {
                let account = Account(address: key.address, type: key.type, url: url)
                accountsByAddress[key.address] = (account, json.sha256T())
            }
        }
    }

    /// List of accounts.
    public var accounts: [Account] {
        return withStateLock {
            accountsByAddress.values.map { $0.account }
        }
    }

    /// Retrieves an account for the given address, if it exists.
    public func account(for address: Address) -> Account? {
        return withStateLock {
            accountsByAddress[address]?.account
        }
    }

    /// Retrieves a key for the given address, if it exists.
    public func key(for address: Address) -> KeystoreKey? {
        return withStateLock {
            keysByAddress[address]
        }
    }

    /// Creates a new account.
    public func createAccount(password: String, type: AccountType) throws -> Account {
        mutationLock.lock()
        defer { mutationLock.unlock() }

        let key = try KeystoreKey(password: password, type: type)
        let url = makeAccountURL(for: key.address)
        let account = Account(address: key.address, type: type, url: url)

        try withStateLock {
            try register(account, key: key)
        }
        return account
    }
    
    /// Saves a cached key and registers its account. An existing address must keep its
    /// registered file URL; saving at the same URL supports `addKey` password updates.
    /// - Throws: `Error.accountAlreadyExists` if the address is registered at another URL
    ///   or a new account's destination is already occupied.
    ///   A changed file throws `CocoaError(.fileLocking)`. Reopen the store before retrying.
    public func addAccount(account: Account) throws {
        mutationLock.lock()
        defer { mutationLock.unlock() }

        try withStateLock {
            guard let key = keysByAddress[account.address] else {
                throw DecryptError.missingAccountKey
            }
            try register(account, key: key)
        }
    }
    
    public func addKey(key: KeystoreKey) throws {
        mutationLock.lock()
        defer { mutationLock.unlock() }

        withStateLock {
            cache(key)
        }
    }

    /// Imports an encrypted JSON key.
    ///
    /// - Parameters:
    ///   - key: key to import
    ///   - password: key password
    ///   - newPassword: password to use for the imported key
    /// - Returns: new account
    public func `import`(json: Data, password: String, newPassword: String) throws -> Account {
        mutationLock.lock()
        defer { mutationLock.unlock() }

        let key = try JSONDecoder().decode(KeystoreKey.self, from: json)
        if self.account(for: key.address) != nil {
            throw Error.accountAlreadyExists
        }

        let newKey: KeystoreKey
        switch key.type {
        case .encryptedKey:
            var privateKey = try key.privateKey(password: password)
            defer {
                privateKey.resetBytes(in: 0..<privateKey.count)
            }
            newKey = try KeystoreKey(password: newPassword, key: privateKey)
        case .hierarchicalDeterministicWallet:
            var privateKey = try key.decryptPayload(password: password)
            defer {
                privateKey.resetBytes(in: 0..<privateKey.count)
            }
            // An HD keystore's ciphertext holds the mnemonic, not a raw scalar, so it has to be
            // rebuilt through the mnemonic path, mirroring `export()` below. Handing the payload
            // to `KeystoreKey(password:key:)` would make the private key the first 32 characters
            // of the mnemonic.
            let (mnemonic, passphrase) = try KeystoreKey.splitMnemonicPayload(privateKey)
            guard Mnemonic.isValid(mnemonic) else {
                throw Error.invalidMnemonic
            }
            newKey = try KeystoreKey(password: newPassword, mnemonic: mnemonic, passphrase: passphrase, derivationPath: key.derivationPath, normalization: .legacy)
        }

        // The address declared inside the JSON must match the address derived from the decrypted
        // secret. This holds for any keystore `export()` produces, so a mismatch means the file
        // was tampered with or carries the wrong type.
        guard newKey.address == key.address else {
            throw Error.invalidKey
        }

        let url = makeAccountURL(for: newKey.address)
        let account = Account(address: newKey.address, type: key.type, url: url)

        try withStateLock {
            guard accountsByAddress[newKey.address] == nil else {
                throw Error.accountAlreadyExists
            }
            try register(account, key: newKey)
        }

        return account
    }

    /// Imports a wallet.
    ///
    /// - Parameters:
    ///   - mnemonic: wallet's mnemonic phrase
    ///   - passphrase: BIP39 passphrase, separate from the keystore encryption password
    ///   - derivationPath: wallet's derivation path
    ///   - encryptPassword: password to use for encrypting
    ///   - normalization: Defaults to BIP39 NFKD; select `.legacy` only when restoring
    ///     a wallet previously created from unnormalized inputs.
    /// - Returns: new account
    public func `import`(mnemonic: String, passphrase: String = "", derivationPath: String = Wallet.defaultPath, encryptPassword: String, normalization: Mnemonic.Normalization = .bip39) throws -> Account {
        mutationLock.lock()
        defer { mutationLock.unlock() }

        let address = try generateWalletAddress(derivationPath: derivationPath, mnemonic: mnemonic,
                                                password: passphrase, normalization: normalization)
        if self.account(for: address) != nil {
            throw Error.accountAlreadyExists
        }

        let newKey = try KeystoreKey(password: encryptPassword, mnemonic: mnemonic, passphrase: passphrase, derivationPath: derivationPath, normalization: normalization)
        let url = makeAccountURL(for: address)
        let account = Account(address: address, type: .hierarchicalDeterministicWallet, url: url)

        try withStateLock {
            guard accountsByAddress[newKey.address] == nil else {
                throw Error.accountAlreadyExists
            }
            try register(account, key: newKey)
        }

        return account
    }

    /// Exports an account as JSON data.
    ///
    /// - Parameters:
    ///   - account: account to export
    ///   - password: account password
    ///   - newPassword: password to use for exported key
    /// - Returns: encrypted JSON key
    public func export(account: Account, password: String, newPassword: String) throws -> Data {
        guard let key = withStateLock({ keysByAddress[account.address] }) else {
            throw DecryptError.missingAccountKey
        }

        let newKey: KeystoreKey
        switch key.type {
        case .encryptedKey:
            var privateKey = try key.privateKey(password: password)
            defer {
                privateKey.resetBytes(in: 0..<privateKey.count)
            }
            newKey = try KeystoreKey(password: newPassword, key: privateKey)
        case .hierarchicalDeterministicWallet:
            var privateKey = try key.decryptPayload(password: password)
            defer {
                privateKey.resetBytes(in: 0..<privateKey.count)
            }
            let (mnemonic, passphrase) = try KeystoreKey.splitMnemonicPayload(privateKey)
            newKey = try KeystoreKey(password: newPassword, preservingStoredMnemonic: mnemonic, passphrase: passphrase, derivationPath: key.derivationPath)
        }
        guard newKey.address == account.address else { throw Error.invalidKey }
        return try JSONEncoder().encode(newKey)
    }

    /// Exports an account as private key data.
    ///
    /// - Parameters:
    ///   - account: account to export
    ///   - password: account password
    /// - Returns: private key data
    public func exportPrivateKey(account: Account, password: String) throws -> Data {
        guard let key = withStateLock({ keysByAddress[account.address] }) else {
            throw DecryptError.missingAccountKey
        }

        return try key.privateKey(password: password)
    }
    
    /// Exports a account as a mnemonic phrase.
    ///
    /// - Parameters:
    ///   - account: account to export
    ///   - password: account password
    /// - Returns: mnemonic phrase
    /// - Throws: `EncryptError.invalidMnemonic` if the account is not an HD wallet.
    public func exportMnemonic(account: Account, password: String) throws -> String {
        guard let key = withStateLock({ keysByAddress[account.address] }) else {
            throw DecryptError.missingAccountKey
        }
        var data = try key.decryptPayload(password: password)
        defer {
            data.resetBytes(in: 0 ..< data.count)
        }
        
        switch key.type {
        case .encryptedKey:
            throw EncryptError.invalidMnemonic
        case .hierarchicalDeterministicWallet:
            return try key.verifiedHDMaterial(data).mnemonic
        }
    }

    /// Updates the password of an existing account.
    ///
    /// A changed or missing registered file causes a storage error. Reopen the store to
    /// load the current account state before retrying.
    ///
    /// - Parameters:
    ///   - account: account to update, retaining its registered key file URL
    ///   - password: current password
    ///   - newPassword: new password
    ///   - derivationPath: optional HD wallet derivation path; defaults to the stored key path
    public func update(account: Account, password: String, newPassword: String, derivationPath: String? = nil) throws {
        mutationLock.lock()
        defer { mutationLock.unlock() }

        guard let key = withStateLock({ keysByAddress[account.address] }) else {
            throw DecryptError.missingAccountKey
        }

        let newKey: KeystoreKey
        switch key.type {
        case .encryptedKey:
            var privateKey = try key.privateKey(password: password)
            defer {
                privateKey.resetBytes(in: 0..<privateKey.count)
            }
            newKey = try KeystoreKey(password: newPassword, key: privateKey)
        case .hierarchicalDeterministicWallet:
            var privateKey = try key.decryptPayload(password: password)
            defer {
                privateKey.resetBytes(in: 0..<privateKey.count)
            }
            let (mnemonic, passphrase) = try KeystoreKey.splitMnemonicPayload(privateKey)
            var path = key.derivationPath
            if let requested = derivationPath, requested != key.derivationPath {
                _ = try key.verifiedHDMaterial(privateKey)
                // Older wallet databases can supply the historical spelling during rotation.
                // The rebuilt key must also match the original address before the write.
                path = DerivationPath.restoringStoredPath(requested)
            }
            newKey = try KeystoreKey(password: newPassword,
                                      preservingStoredMnemonic: mnemonic,
                                      passphrase: passphrase,
                                      derivationPath: path)
        }
        guard newKey.address == key.address else {
            throw Error.invalidKey
        }
        try withStateLock {
            let digest = try save(key: newKey, to: account.url)
            accountsByAddress[account.address]?.fileDigest = digest
            cache(newKey)
        }
    }

    /// Deletes an account including its key if the password is correct.
    public func delete(account: Account, password: String) throws {
        try removeAccount(account, password: password) { try FileManager.default.removeItem(at: $0) }
    }

    /// Moves the authenticated file to an unused sibling URL before unregistering the account.
    /// The caller owns the backup until commit or rollback. A visible backup in the
    /// key directory can be loaded as an account when the store is reopened.
    public func moveToDeletionBackup(account: Account, password: String, backupURL: URL,
                                     fileManager: FileManager = .default) throws {
        try removeAccount(account, password: password) { source in
            guard backupURL.isFileURL, source.standardizedFileURL != backupURL.standardizedFileURL,
                  source.deletingLastPathComponent().standardizedFileURL == backupURL.deletingLastPathComponent().standardizedFileURL else {
                throw CocoaError(.fileWriteInvalidFileName)
            }
            try fileManager.moveItem(at: source, to: backupURL)
        }
    }

    private func removeAccount(_ account: Account, password: String, removeFile: (URL) throws -> Void) throws {
        mutationLock.lock()
        defer { mutationLock.unlock() }

        guard let storedAccount = withStateLock({ accountsByAddress[account.address]?.account }) else {
            throw DecryptError.missingAccountKey
        }
        let original = try Data(contentsOf: storedAccount.url)
        let key = try JSONDecoder().decode(KeystoreKey.self, from: original)
        guard key.address == account.address else { throw Error.invalidKey }
        var decryptedKey = try key.decryptPayload(password: password)
        decryptedKey.resetBytes(in: 0..<decryptedKey.count)

        try withStateLock {
            guard !hasUnreadableAccounts else {
                throw CocoaError(.fileReadUnknown)
            }
            // A second file may have appeared since this store loaded the account.
            let urls = try FileManager.default.contentsOfDirectory(at: keyDirectory,
                includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
            for url in urls where url.standardizedFileURL != storedAccount.url.standardizedFileURL {
                if try url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true { continue }
                let data = try Data(contentsOf: url)
                if let other = try? JSONDecoder().decode(KeystoreKey.self, from: data),
                   other.address == account.address {
                    throw Error.accountAlreadyExists
                }
            }
            try withCommitLock(for: storedAccount.url) {
                guard try Data(contentsOf: storedAccount.url) == original else {
                    throw Error.invalidKey
                }
                try removeFile(storedAccount.url)
            }
            keysByAddress[account.address] = nil
            accountsByAddress[account.address] = nil
        }
    }

    /// Calculates a ECDSA signature for the give hash.
    ///
    /// - Parameters:
    ///   - data: hash to sign
    ///   - account: account to use for signing
    ///   - password: account password
    /// - Returns: signature
    /// - Throws: `DecryptError`, `Secp256k1Error`, or `KeyStore.Error`
    public func signHash(_ data: Data, account: Account, password: String) throws -> Data {
        guard let key = withStateLock({ keysByAddress[account.address] }) else {
            throw KeyStore.Error.accountNotFound
        }
        return try key.sign(hash: data, password: password)
    }

    /// Signs an array of hashes with the given password.
    ///
    /// - Parameters:
    ///   - hashes: array of hashes to sign
    ///   - account: account to use for signing
    ///   - password: key password
    /// - Returns: array of signatures
    /// - Throws: `DecryptError` or `Secp256k1Error` or `KeyStore.Error`
    public func signHashes(_ data: [Data], account: Account, password: String) throws -> [Data] {
        guard let key = withStateLock({ keysByAddress[account.address] }) else {
            throw KeyStore.Error.accountNotFound
        }
        return try key.signHashes(data, password: password)
    }

    // MARK: Helpers

    private func makeAccountURL(for address: Address) -> URL {
        return keyDirectory.appendingPathComponent(generateFileName(address: address))
    }

    private func withStateLock<T>(_ body: () throws -> T) rethrows -> T {
        stateLock.lock()
        defer { stateLock.unlock() }
        if backupExclusionPending {
            retryDirectoryBackupExclusion()
        }
        // ponytail: retry pending files on access; use a protected-data notification if retry I/O becomes costly.
        if directoryListingPending {
            load()
        } else if !pendingAccountURLs.isEmpty {
            loadAccounts(at: pendingAccountURLs)
        }
        return try body()
    }

    /// Retains encrypted key material for the process lifetime.
    private func cache(_ key: KeystoreKey) {
        keysByAddress[key.address] = key
    }

    /// Generates a unique file name for an address.
    func generateFileName(address: Address, date: Date = Date(), timeZone: TimeZone = .current) -> String {
        // keyFileName implements the naming convention for keyfiles:
        // UTC--<created_at UTC ISO8601>-<address hex>
        return "UTC--\(filenameTimestamp(for: date, in: timeZone))--\(address.data.hexString)"
    }

    private func filenameTimestamp(for date: Date, in timeZone: TimeZone = .current) -> String {
        var tz = ""
        let offset = timeZone.secondsFromGMT()
        if offset == 0 {
            tz = "Z"
        } else {
            tz = String(format: "%03d00", offset/60)
        }

        let components = Calendar(identifier: .iso8601).dateComponents(in: timeZone, from: date)
        return String(format: "%04d-%02d-%02dT%02d-%02d-%02d.%09d%@", components.year!, components.month!, components.day!, components.hour!, components.minute!, components.second!, components.nanosecond!, tz)
    }

    private func register(_ account: Account, key: KeystoreKey) throws {
        let digest = try save(key: key, to: account.url)
        accountsByAddress[key.address] = (account, digest)
        cache(key)
    }

    // Lock the parent directory: the destination inode changes on every atomic replacement.
    // Separate opens coordinate writers across instances and processes without a sidecar file.
    private func withCommitLock(for url: URL, _ body: () throws -> Void) throws {
        let directory = url.deletingLastPathComponent().path
        var fd: Int32
        repeat {
            fd = open(directory, O_RDONLY | O_DIRECTORY | O_EXLOCK | O_CLOEXEC)
        } while fd == -1 && errno == EINTR
        guard fd != -1 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: nil)
        }
        defer { _ = close(fd) }
        try body()
    }

    private func save(key: KeystoreKey, to url: URL) throws -> Data {
        // Unknown files may contain the same address; finish loading before changing disk state.
        guard !hasUnreadableAccounts else {
            throw CocoaError(.fileReadUnknown)
        }
        // One address has one managed key file. A second path would leave the old key
        // behind after password changes or deletion. Keep same-path updates working.
        let registeredAccount = accountsByAddress[key.address]
        if let registered = registeredAccount, registered.account.url.standardizedFileURL != url.standardizedFileURL {
            throw Error.accountAlreadyExists
        }
        let json = try JSONEncoder().encode(key)
        backupExclusionPending = true
        try excludeFromBackup(at: keyDirectory)
        backupExclusionPending = false
        let temporaryURL = url.deletingLastPathComponent().appendingPathComponent(".keystore-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: temporaryURL) }
        // Exclude the empty file before any key material reaches an external directory.
        try Data().write(to: temporaryURL, options: [.withoutOverwriting, .completeFileProtection])
        try excludeFromBackup(at: temporaryURL)
        let handle = try FileHandle(forWritingTo: temporaryURL)
        defer { try? handle.close() }
        try handle.write(contentsOf: json)
        try handle.synchronize()
        try handle.close()
        if let registered = registeredAccount {
            try withCommitLock(for: url) {
                let current = try Data(contentsOf: url)
                guard current.sha256T() == registered.fileDigest else {
                    throw CocoaError(.fileLocking)
                }
                guard rename(temporaryURL.path, url.path) == 0 else {
                    throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: nil)
                }
            }
        } else if renamex_np(temporaryURL.path, url.path, UInt32(RENAME_EXCL)) != 0 {
            let code = errno
            if code == EEXIST { throw Error.accountAlreadyExists }
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(code), userInfo: nil)
        }
        return json.sha256T()
    }

    private func retryDirectoryBackupExclusion() {
        do {
            try excludeFromBackup(at: keyDirectory)
            backupExclusionPending = false
        } catch {
            // Keep initialization recoverable; save still requires successful exclusion.
            backupExclusionPending = true
        }
    }

    private func excludeFromBackup(at url: URL) throws {
        var resourceURL = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try resourceURL.setResourceValues(values)
        resourceURL.removeCachedResourceValue(forKey: .isExcludedFromBackupKey)
        guard try resourceURL.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true else {
            throw CocoaError(.fileWriteUnknown)
        }
    }
}

extension KeyStore {
    public func checkingAccountAlreadyExists(json: Data, password: String, newPassword: String) throws -> Bool {
        let key = try JSONDecoder().decode(KeystoreKey.self, from: json)
        if self.account(for: key.address) != nil {
            throw Error.accountAlreadyExists
        }
        return false
    }

    public func checkingAccountAlreadyExists(mnemonic: String, passphrase: String = "", derivationPath: String = Wallet.defaultPath, encryptPassword: String, normalization: Mnemonic.Normalization = .bip39) throws -> Bool {
        let address = try generateWalletAddress(derivationPath: derivationPath, mnemonic: mnemonic,
                                                password: passphrase, normalization: normalization)
        if self.account(for: address) != nil {
            throw Error.accountAlreadyExists
        }
        return false
    }
    
    /// Generate an address with mnemonic derivationPath.
    /// `password` is the BIP39 passphrase. Use the same normalization when importing the wallet.
    public func generateWalletAddress(derivationPath:String = Wallet.defaultPath,mnemonic:String,password:String = "", normalization: Mnemonic.Normalization = .bip39) throws -> Address{
        let seedMnemonic = Mnemonic.normalize(mnemonic, using: normalization)
        guard Mnemonic.isValid(seedMnemonic) else { throw Error.invalidMnemonic }
        let wallet = try Wallet(mnemonic: seedMnemonic, passphrase: password, path: derivationPath, normalization: normalization)
        let pubKey = try wallet.getKey(at: 0).publicKey
        return try KeystoreKey.decodeAddress(from: pubKey)
    }
    
    /// get an path with account.
    public func generateWalletPath(account: Account) throws -> String {
        return try withStateLock {
            guard let key = keysByAddress[account.address] else {
                throw DecryptError.missingAccountKey
            }
            return key.derivationPath
        }
    }
}
