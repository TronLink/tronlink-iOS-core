import BigInt
import Foundation

public enum Web3Error: Error {
    case transactionSerializationError
    case connectionError
    case dataError
    case inputError(String)
    case nodeError(String)
    case processingError(String)

    public var localizedDescription: String {
        switch self {
        case .transactionSerializationError:
            return "Transaction serialization failed"
        case .connectionError:
            return "Cannot connect to local node"
        case .dataError:
            return "Cannot decode data"
        case let .inputError(string):
            return "Input error: \(string)"
        case let .nodeError(string):
            return "Node error: \(string)"
        case let .processingError(string):
            return "Processing error: \(string)"
        }
    }
}

extension Web3Address: Decodable, Encodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(try container.decode(String.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(address.lowercased())
    }
}

private func decodeHexToData<T>(
    _ container: KeyedDecodingContainer<T>,
    key: KeyedDecodingContainer<T>.Key,
    allowOptional: Bool = false
) throws -> Data? {
    if allowOptional {
        guard let string = try? container.decode(String.self, forKey: key) else { return nil }
        guard let data = Data.fromHex(string) else { throw Web3Error.dataError }
        return data
    }
    let string = try container.decode(String.self, forKey: key)
    guard let data = Data.fromHex(string) else { throw Web3Error.dataError }
    return data
}

private func decodeHexToBigUInt<T>(
    _ container: KeyedDecodingContainer<T>,
    key: KeyedDecodingContainer<T>.Key,
    allowOptional: Bool = false
) throws -> BigUInt? {
    if allowOptional {
        guard let string = try? container.decode(String.self, forKey: key) else { return nil }
        guard let number = BigUInt(string.withoutHex, radix: 16) else { throw Web3Error.dataError }
        return number
    }
    let string = try container.decode(String.self, forKey: key)
    guard let number = BigUInt(string.withoutHex, radix: 16) else { throw Web3Error.dataError }
    return number
}

public struct EventLog: Decodable {
    public var address: Web3Address
    public var blockHash: Data
    public var blockNumber: BigUInt
    public var data: Data
    public var logIndex: BigUInt
    public var removed: Bool
    public var topics: [Data]
    public var transactionHash: Data
    public var transactionIndex: BigUInt

    enum CodingKeys: String, CodingKey {
        case address
        case blockHash
        case blockNumber
        case data
        case logIndex
        case removed
        case topics
        case transactionHash
        case transactionIndex
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        address = try container.decode(Web3Address.self, forKey: .address)
        guard let decodedBlockNumber = try decodeHexToBigUInt(container, key: .blockNumber),
              let decodedBlockHash = try decodeHexToData(container, key: .blockHash),
              let decodedTransactionIndex = try decodeHexToBigUInt(container, key: .transactionIndex),
              let decodedTransactionHash = try decodeHexToData(container, key: .transactionHash),
              let decodedData = try decodeHexToData(container, key: .data),
              let decodedLogIndex = try decodeHexToBigUInt(container, key: .logIndex) else {
            throw Web3Error.dataError
        }
        blockNumber = decodedBlockNumber
        blockHash = decodedBlockHash
        transactionIndex = decodedTransactionIndex
        transactionHash = decodedTransactionHash
        data = decodedData
        logIndex = decodedLogIndex
        removed = try decodeHexToBigUInt(container, key: .removed, allowOptional: true) == 1
        topics = try container.decode([String].self, forKey: .topics).map {
            guard let topic = Data.fromHex($0) else { throw Web3Error.dataError }
            return topic
        }
    }
}
