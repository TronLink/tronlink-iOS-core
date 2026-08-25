
import Foundation

/// Manages directories of key and wallet files and presents them as accounts.
public final class KeyStore {
    /// The key file directory.
    public let keyDirectory: URL

    /// Dictionary of accounts by address.
    private var accountsByAddress = [Address: Account]()

    /// Dictionary of keys by address.
    private var keysByAddress = [Address: KeystoreKey]()

    /// Mutations always acquire this lock before `stateLock`; reads only acquire `stateLock`.
    private let mutationLock = NSLock()
    private let stateLock = NSLock()

    /// Creates a `KeyStore` for the given directory.
    public init(keyDirectory: URL) throws {
        self.keyDirectory = keyDirectory
        try load()
    }

    private func load() throws {
        let fileManager = FileManager.default
        try? fileManager.createDirectory(at: keyDirectory, withIntermediateDirectories: true, attributes: nil)

        let accountURLs = try fileManager.contentsOfDirectory(at: keyDirectory, includingPropertiesForKeys: [], options: [.skipsHiddenFiles])
        for url in accountURLs {
            do {
                let key = try KeystoreKey(contentsOf: url)
                cache(key)
                let account = Account(address: key.address, type: key.type, url: url)
                accountsByAddress[key.address] = account
            } catch {
                // Ignore invalid keys
            }
        }
    }

    /// List of accounts.
    public var accounts: [Account] {
        return withStateLock {
            Array(accountsByAddress.values)
        }
    }

    /// Retrieves an account for the given address, if it exists.
    public func account(for address: Address) -> Account? {
        return withStateLock {
            accountsByAddress[address]
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
            try save(key: key, to: url)
            cache(key)
            accountsByAddress[key.address] = account
        }
        return account
    }
    
    public func addAccount(account: Account) throws {
        mutationLock.lock()
        defer { mutationLock.unlock() }

        try withStateLock {
            guard let key = keysByAddress[account.address] else {
                throw DecryptError.missingAccountKey
            }
            try save(key: key, to: account.url)
            accountsByAddress[account.address] = account
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
            var privateKey = try key.decrypt(password: password)
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
            newKey = try KeystoreKey(password: newPassword, mnemonic: mnemonic, passphrase: passphrase, derivationPath: key.derivationPath)
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
            try save(key: newKey, to: url)
            cache(newKey)
            accountsByAddress[newKey.address] = account
        }

        return account
    }

    /// Imports a wallet.
    ///
    /// - Parameters:
    ///   - mnemonic: wallet's mnemonic phrase
    ///   - passphrase: wallet's password
    ///   - derivationPath: wallet's derivation path
    ///   - encryptPassword: password to use for encrypting
    /// - Returns: new account
    public func `import`(mnemonic: String, passphrase: String = "", derivationPath: String = Wallet.defaultPath, encryptPassword: String) throws -> Account {
        mutationLock.lock()
        defer { mutationLock.unlock() }

        if !Mnemonic.isValid(mnemonic) {
            throw Error.invalidMnemonic
        }

        let wallet = try Wallet(mnemonic: mnemonic, passphrase: passphrase, path: derivationPath)
        let pubKey = try wallet.getKey(at: 0).publicKey
        let address = try KeystoreKey.decodeAddress(from: pubKey)
        if self.account(for: address) != nil {
            throw Error.accountAlreadyExists
        }

        let newKey = try KeystoreKey(password: encryptPassword, mnemonic: mnemonic, passphrase: passphrase, derivationPath: derivationPath)
        let url = makeAccountURL(for: address)
        let account = Account(address: address, type: .hierarchicalDeterministicWallet, url: url)

        try withStateLock {
            try save(key: newKey, to: url)
            cache(newKey)
            accountsByAddress[newKey.address] = account
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
            var privateKey = try key.decrypt(password: password)
            defer {
                privateKey.resetBytes(in: 0..<privateKey.count)
            }
            let (mnemonic, passphrase) = try KeystoreKey.splitMnemonicPayload(privateKey)
            newKey = try KeystoreKey(password: newPassword, mnemonic: mnemonic, passphrase: passphrase, derivationPath: key.derivationPath)
        }
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

        switch key.type {
        case .encryptedKey:
            var privateKey = try key.privateKey(password: password)
            defer {
                privateKey.resetBytes(in: 0..<privateKey.count)
            }
            return privateKey
        case .hierarchicalDeterministicWallet:
            var privateKey = try key.decrypt(password: password)
            defer {
                privateKey.resetBytes(in: 0..<privateKey.count)
            }
            let (mnemonic, passphrase) = try KeystoreKey.splitMnemonicPayload(privateKey)
            return try Wallet(mnemonic: mnemonic, passphrase: passphrase, path: key.derivationPath).getKey(at: 0).privateKey
        }
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
        var data = try key.decrypt(password: password)
        defer {
            data.resetBytes(in: 0 ..< data.count)
        }
        
        switch key.type {
        case .encryptedKey:
            throw EncryptError.invalidMnemonic
        case .hierarchicalDeterministicWallet:
            return try KeystoreKey.splitMnemonicPayload(data).mnemonic
        }
    }

    /// Updates the password of an existing account.
    ///
    /// - Parameters:
    ///   - account: account to update
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
            var privateKey = try key.decrypt(password: password)
            defer {
                privateKey.resetBytes(in: 0..<privateKey.count)
            }
            let (mnemonic, passphrase) = try KeystoreKey.splitMnemonicPayload(privateKey)
            newKey = try KeystoreKey(password: newPassword,
                                      mnemonic: mnemonic,
                                      passphrase: passphrase,
                                      derivationPath: derivationPath ?? key.derivationPath)
        }
        guard newKey.address == key.address else {
            throw Error.invalidKey
        }
        try withStateLock {
            try save(key: newKey, to: account.url)
            cache(newKey)
        }
    }

    /// Deletes an account including its key if the password is correct.
    public func delete(account: Account, password: String) throws {
        mutationLock.lock()
        defer { mutationLock.unlock() }

        let (key, storedAccount) = try withStateLock { () -> (KeystoreKey, Account) in
            guard let key = keysByAddress[account.address],
                  let storedAccount = accountsByAddress[account.address] else {
                throw DecryptError.missingAccountKey
            }
            return (key, storedAccount)
        }
        var decryptedKey = try key.decrypt(password: password)
        decryptedKey.resetBytes(in: 0..<decryptedKey.count)

        try withStateLock {
            try FileManager.default.removeItem(at: storedAccount.url)
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

    private func save(key: KeystoreKey, to url: URL) throws {
        let json = try JSONEncoder().encode(key)
        try json.write(to: url, options: [.atomicWrite])
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

    public func checkingAccountAlreadyExists(mnemonic: String, passphrase: String = "", derivationPath: String = Wallet.defaultPath, encryptPassword: String) throws -> Bool {
        if !Mnemonic.isValid(mnemonic) {
            throw Error.invalidMnemonic
        }
        
        let wallet = try Wallet(mnemonic: mnemonic, passphrase: passphrase, path: derivationPath)
        let pubKey = try wallet.getKey(at: 0).publicKey
        let address = try KeystoreKey.decodeAddress(from: pubKey)
        if self.account(for: address) != nil {
            throw Error.accountAlreadyExists
        }
        return false
    }
    
    /// Generate an address with mnemonic derivationPath.
    public func generateWalletAddress(derivationPath:String = Wallet.defaultPath,mnemonic:String,password:String = "") throws -> Address{
        let wallet = try Wallet(mnemonic: mnemonic, passphrase: password, path: derivationPath)
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
