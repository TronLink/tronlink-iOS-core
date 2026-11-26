
import Foundation
import Darwin

/// Manages directories of key and wallet files and presents them as accounts.
public final class KeyStore {
    /// A hidden sibling with this extension is a pending deletion, never a live account.
    /// Until the caller finishes recovery its address cannot be newly registered.
    public static let deletionBackupFileExtension = "wallet-delete-backup"
    private static let externalReferencePrefix = ".keystore-external-"
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

    private func hasRegisteredAccount(for address: Address) -> Bool {
        let identity = address.keystoreIdentity
        return withStateLock { accountsByAddress.keys.contains { $0.keystoreIdentity == identity } }
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
        if hasRegisteredAccount(for: key.address) {
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
        try key.verifyDerivedAddress(newKey.address)

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
        if hasRegisteredAccount(for: address) {
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
        // Backups use the canonical TRON address, including for legacy Ethereum V3 inputs.
        try key.verifyDerivedAddress(newKey.address)
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

        var newKey: KeystoreKey
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
        try key.verifyDerivedAddress(newKey.address)
        // An in-place password change keeps the on-disk and cached account identifier.
        newKey.address = key.address
        try withStateLock {
            let digest = try save(key: newKey, to: account.url)
            accountsByAddress[account.address]?.fileDigest = digest
            cache(newKey)
        }
    }

    /// Deletes an account including its key if the password is correct.
    public func delete(account: Account, password: String) throws {
        try removeAccount(account, password: password, keepingBackup: false) { try FileManager.default.removeItem(at: $0) }
    }

    /// Moves the authenticated file to an unused sibling URL before unregistering the account.
    /// The caller owns the backup until commit or rollback. A visible backup in the
    /// key directory can be loaded as an account when the store is reopened.
    /// Hidden backups reserve their address until the caller removes or restores them.
    public func moveToDeletionBackup(account: Account, password: String, backupURL: URL,
                                     fileManager: FileManager = .default) throws {
        try removeAccount(account, password: password, keepingBackup: true) { source in
            guard backupURL.isFileURL, source.standardizedFileURL != backupURL.standardizedFileURL,
                  !isInternalFile(backupURL),
                  source.deletingLastPathComponent().standardizedFileURL == backupURL.deletingLastPathComponent().standardizedFileURL else {
                throw CocoaError(.fileWriteInvalidFileName)
            }
            try fileManager.moveItem(at: source, to: backupURL)
        }
    }

    private func removeAccount(_ account: Account, password: String, keepingBackup: Bool, removeFile: (URL) throws -> Void) throws {
        mutationLock.lock()
        defer { mutationLock.unlock() }

        guard let storedAccount = withStateLock({ accountsByAddress[account.address]?.account }) else {
            throw DecryptError.missingAccountKey
        }
        let original = try Data(contentsOf: storedAccount.url)
        let key = try JSONDecoder().decode(KeystoreKey.self, from: original)
        guard key.address == account.address else { throw Error.invalidKey }
        var decryptedKey = try key.decrypt(password: password)
        decryptedKey.resetBytes(in: 0..<decryptedKey.count)

        try withStateLock {
            guard !hasUnreadableAccounts else {
                throw CocoaError(.fileReadUnknown)
            }
            try commitFile(for: account.address, at: storedAccount.url, keepExternalDirectory: keepingBackup) {
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

    private func isInternalFile(_ url: URL) -> Bool {
        let name = url.lastPathComponent.lowercased()
        if name.hasPrefix(Self.externalReferencePrefix) {
            let digest = String(name.dropFirst(Self.externalReferencePrefix.count))
            return digest.utf8.count == 64 && Data(hexString: digest)?.count == 32
        }
        let prefix = ".keystore-"
        return name.hasPrefix(prefix) && UUID(uuidString: String(name.dropFirst(prefix.count))) != nil
    }

    // Hidden wallet files include backups named by older hosts, e.g. ".rollback".
    private func rejectOtherFiles(for address: Address, in directory: URL, excluding destination: URL) throws {
        let identity = address.keystoreIdentity
        let metadata: Set<URLResourceKey> = [.isDirectoryKey, .isRegularFileKey, .isHiddenKey]
        let urls = try FileManager.default.contentsOfDirectory(at: directory,
            includingPropertiesForKeys: Array(metadata),
            options: [])
        for url in urls where url.standardizedFileURL.path != destination.standardizedFileURL.path && !isInternalFile(url) {
            let values = try url.resourceValues(forKeys: metadata)
            if values.isDirectory == true { continue }
            let hidden = url.lastPathComponent.hasPrefix(".") || values.isHidden == true
            // Also support external registration in a directory with non-wallet entries.
            // Never open a pipe/device while holding the directory lock.
            if values.isRegularFile != true {
                let target = try url.resolvingSymlinksInPath().resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey])
                if target.isDirectory == true { continue }
                if target.isRegularFile != true {
                    if hidden && url.pathExtension != Self.deletionBackupFileExtension { continue }
                    throw CocoaError(.fileReadUnknown)
                }
            }
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            if let other = try? JSONDecoder().decode(KeystoreKey.self, from: data), other.address.keystoreIdentity == identity {
                if hidden { throw CocoaError(.fileLocking) }
                throw Error.accountAlreadyExists
            }
        }
    }

    // Only an externally stored account needs a directory reference. Keep it across a
    // deletion backup so another process can see both a rollback and a completed deletion.
    private func commitFile(for address: Address, at url: URL, keepExternalDirectory: Bool, _ body: () throws -> Void) throws {
        let managed = keyDirectory.resolvingSymlinksInPath().standardizedFileURL
        let parent = url.deletingLastPathComponent().resolvingSymlinksInPath().standardizedFileURL
        let destination = parent.appendingPathComponent(url.lastPathComponent)
        let reference = managed.appendingPathComponent(Self.externalReferencePrefix + address.keystoreIdentity.sha256T().hexString)
        while true {
            let previous = try externalDirectoryReference(at: reference)
            var directories = [parent, managed]
            if let previous = previous {
                directories.append(managed.appendingPathComponent(previous, isDirectory: true).standardizedFileURL)
            }
            let committed = try withDirectoryLocks(directories) { locked, isExternal in
                // Another writer may have changed the reference while we acquired the locks.
                guard try externalDirectoryReference(at: reference) == previous else { return false }
                for directory in locked {
                    try rejectOtherFiles(for: address, in: directory, excluding: destination)
                }
                let next: String?
                if keepExternalDirectory && isExternal {
                    let from = managed.pathComponents
                    let to = parent.pathComponents
                    let common = zip(from, to).prefix(while: { $0.0 == $0.1 }).count
                    next = (Array(repeating: "..", count: from.count - common) + Array(to.dropFirst(common))).joined(separator: "/")
                } else {
                    next = nil
                }
                if let next = next, next != previous {
                    // Publish the reference before the file. A crash here leaves an empty
                    // directory reservation that the next registration can reuse.
                    try writeExternalDirectoryReference(next, at: reference)
                }
                do {
                    try body()
                } catch {
                    if next != nil && next != previous {
                        try writeExternalDirectoryReference(previous, at: reference)
                    }
                    throw error
                }
                if previous != nil && next == nil {
                    try? FileManager.default.removeItem(at: reference)
                }
                return true
            }
            if committed { return }
        }
    }

    private func writeExternalDirectoryReference(_ path: String?, at url: URL) throws {
        if let path = path {
            try Data(path.utf8).write(to: url, options: [.atomic, .completeFileProtection])
        } else {
            try FileManager.default.removeItem(at: url)
        }
    }

    private func externalDirectoryReference(at url: URL) throws -> String? {
        var fd: Int32
        repeat { fd = open(url.path, O_RDONLY | O_CLOEXEC | O_NONBLOCK | O_NOFOLLOW) } while fd == -1 && errno == EINTR
        if fd == -1 && errno == ENOENT { return nil }
        guard fd != -1 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        defer { try? handle.close() }
        var info = stat()
        guard fstat(fd, &info) == 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        // A relative path can contain a ".." for every component of the base path.
        let limit = 3 * Int(PATH_MAX)
        guard (info.st_mode & mode_t(S_IFMT)) == mode_t(S_IFREG), info.st_size > 0, info.st_size <= off_t(limit),
              let data = try handle.read(upToCount: limit), data.count == Int(info.st_size),
              let path = String(data: data, encoding: .utf8), !path.hasPrefix("/"), !data.contains(0) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return path
    }

    // The first two directories are the destination and managed directory. A previous
    // external directory can disappear after its owner removes the wallet or backup.
    // Device/inode order is stable across path aliases and opposite-direction registrations.
    private func withDirectoryLocks(_ directories: [URL], _ body: ([URL], Bool) throws -> Bool) throws -> Bool {
        var handles = [(url: URL, fd: Int32, device: dev_t, inode: ino_t)]()
        var isExternal = false
        defer { for handle in handles { _ = close(handle.fd) } }
        for (index, directory) in directories.enumerated() {
            var fd: Int32
            repeat { fd = open(directory.path, O_RDONLY | O_DIRECTORY | O_CLOEXEC) } while fd == -1 && errno == EINTR
            if fd == -1 && index >= 2 && (errno == ENOENT || errno == ENOTDIR) { continue }
            guard fd != -1 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
            var info = stat()
            if fstat(fd, &info) != 0 {
                let error = errno
                _ = close(fd)
                throw NSError(domain: NSPOSIXErrorDomain, code: Int(error))
            }
            if handles.contains(where: { $0.device == info.st_dev && $0.inode == info.st_ino }) {
                _ = close(fd)
            } else {
                handles.append((directory, fd, info.st_dev, info.st_ino))
                if index == 1 { isExternal = true }
            }
        }
        handles.sort { ($0.device, $0.inode) < ($1.device, $1.inode) }
        for handle in handles {
            var result: Int32
            repeat { result = flock(handle.fd, LOCK_EX) } while result == -1 && errno == EINTR
            guard result == 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        }
        return try body(handles.map { $0.url }, isExternal)
    }

    private func save(key: KeystoreKey, to url: URL) throws -> Data {
        guard !isInternalFile(url) else { throw CocoaError(.fileWriteInvalidFileName) }
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
        try commitFile(for: key.address, at: url, keepExternalDirectory: true) {
            if let registered = registeredAccount {
                let current = try Data(contentsOf: url)
                guard current.sha256T() == registered.fileDigest else {
                    throw CocoaError(.fileLocking)
                }
                guard rename(temporaryURL.path, url.path) == 0 else {
                    throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: nil)
                }
            } else {
                if renamex_np(temporaryURL.path, url.path, UInt32(RENAME_EXCL)) != 0 {
                    let code = errno
                    if code == EEXIST { throw Error.accountAlreadyExists }
                    throw NSError(domain: NSPOSIXErrorDomain, code: Int(code), userInfo: nil)
                }
            }
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
        if hasRegisteredAccount(for: key.address) {
            throw Error.accountAlreadyExists
        }
        return false
    }

    public func checkingAccountAlreadyExists(mnemonic: String, passphrase: String = "", derivationPath: String = Wallet.defaultPath, encryptPassword: String, normalization: Mnemonic.Normalization = .bip39) throws -> Bool {
        let address = try generateWalletAddress(derivationPath: derivationPath, mnemonic: mnemonic,
                                                password: passphrase, normalization: normalization)
        if hasRegisteredAccount(for: address) {
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
