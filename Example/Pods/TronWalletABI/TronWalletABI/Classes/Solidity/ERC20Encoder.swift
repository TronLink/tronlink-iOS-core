
import BigInt
import Foundation

/// Encodes ERC20 function calls.
public final class ERC20Encoder {
    /// Encodes a function call to `totalSupply`
    ///
    /// Solidity function: `function totalSupply() public constant returns (uint);`
    public static func encodeTotalSupply() -> Data {
        let function = Function(name: "totalSupply", parameters: [])
        let encoder = ABIEncoder()
        try! encoder.encode(function: function, arguments: [])
        return encoder.data
    }

    /// Encodes a function call to `name`
    ///
    /// Solidity function: `string public constant name = "Token Name";`
    public static func encodeName() -> Data {
        let function = Function(name: "name", parameters: [])
        let encoder = ABIEncoder()
        try! encoder.encode(function: function, arguments: [])
        return encoder.data
    }

    /// Encodes a function call to `symbol`
    ///
    /// Solidity function: `string public constant symbol = "SYM";`
    public static func encodeSymbol() -> Data {
        let function = Function(name: "symbol", parameters: [])
        let encoder = ABIEncoder()
        try! encoder.encode(function: function, arguments: [])
        return encoder.data
    }

    /// Encodes a function call to `decimals`
    ///
    /// Solidity function: `uint8 public constant decimals = 18;`
    public static func encodeDecimals() -> Data {
        let function = Function(name: "decimals", parameters: [])
        let encoder = ABIEncoder()
        try! encoder.encode(function: function, arguments: [])
        return encoder.data
    }

    /// Encodes a function call to `balanceOf`
    ///
    /// Solidity function: `function balanceOf(address tokenOwner) public constant returns (uint balance);`
    public static func encodeBalanceOf(address: Address) -> Data {
        let function = Function(name: "balanceOf", parameters: [.address])
        let encoder = ABIEncoder()
        try! encoder.encode(function: function, arguments: [address])
        return encoder.data
    }

    /// Encodes a function call to `allowance`
    ///
    /// Solidity function: `function allowance(address tokenOwner, address spender) public constant returns (uint remaining);`
    public static func encodeAllowance(owner: Address, spender: Address) -> Data {
        let function = Function(name: "allowance", parameters: [.address, .address])
        let encoder = ABIEncoder()
        try! encoder.encode(function: function, arguments: [owner, spender])
        return encoder.data
    }

    /// Encodes a function call to `transfer`
    ///
    /// Solidity function: `function transfer(address to, uint tokens) public returns (bool success);`
    public static func encodeTransfer(to: Address, tokens: BigUInt) -> Data {
        let function = Function(name: "transfer", parameters: [.address, .uint(bits: 256)])
        let encoder = ABIEncoder()
        try! encoder.encode(function: function, arguments: [to, tokens])
        return encoder.data
    }

    /// Encodes a function call to `approve`
    ///
    /// Solidity function: `function approve(address spender, uint tokens) public returns (bool success);`
    public static func encodeApprove(spender: Address, tokens: BigUInt) -> Data {
        let function = Function(name: "approve", parameters: [.address, .uint(bits: 256)])
        let encoder = ABIEncoder()
        try! encoder.encode(function: function, arguments: [spender, tokens])
        return encoder.data
    }

    /// Encodes a function call to `transferFrom`
    ///
    /// Solidity function: `function transferFrom(address from, address to, uint tokens) public returns (bool success);`
    public static func encodeTransfer(from: Address, to: Address, tokens: BigUInt) -> Data {
        let function = Function(name: "transferFrom", parameters: [.address, .address, .uint(bits: 256)])
        let encoder = ABIEncoder()
        try! encoder.encode(function: function, arguments: [from, to, tokens])
        return encoder.data
    }
    
    /// Encodes a function call to `depositTRX`
    ///
    /// Solidity function: `function depositTRX() public returns (bool success);`
    public static func encodeDepositTRX() -> Data {
        let function = Function(name: "depositTRX", parameters: [])
        let encoder = ABIEncoder()
        try! encoder.encode(function: function, arguments: [])
        return encoder.data
    }
    
    /// Encodes a function call to `depositTRC10`
    ///
    /// Solidity function: `function depositTRC10(uint tokenID, uint tokenCount) public returns (bool success);`
    public static func encodeDepositTRC10(tokenId: BigUInt, tokens: BigUInt) -> Data {
        let function = Function(name: "depositTRC10", parameters: [.uint(bits: 64), .uint(bits: 64)])
        let encoder = ABIEncoder()
        try! encoder.encode(function: function, arguments: [tokenId, tokens])
        return encoder.data
    }
    
    /// Encodes a function call to `encodeDepositTRC20`
    ///
    /// Solidity function: `function encodeDepositTRC20(address spender, uint tokens) public returns (bool success);`
    public static func encodeDepositTRC20(spender: Address, tokens: BigUInt) -> Data {
        let function = Function(name: "depositTRC20", parameters: [.address, .uint(bits: 64)])
        let encoder = ABIEncoder()
        try! encoder.encode(function: function, arguments: [spender, tokens])
        return encoder.data
    }
    
    /// Encodes a function call to `encodeWithdrawTRX`
    ///
    /// Solidity function: `function encodeWithdrawTRX() public returns (bool success);`
    public static func encodeWithdrawTRX() -> Data {
        let function = Function(name: "withdrawTRX", parameters: [])
        let encoder = ABIEncoder()
        try! encoder.encode(function: function, arguments: [])
        return encoder.data
    }
    
    /// Encodes a function call to `encodeWithdrawFee`
    ///
    /// Solidity function: `function encodeWithdrawFee() public returns (uint256 public constant);`
    public static func encodeWithdrawFee() -> Data {
        let function = Function(name: "getWithdrawFee", parameters: [])
        let encoder = ABIEncoder()
        try! encoder.encode(function: function, arguments: [])
        return encoder.data
    }
    
    /// Encodes a function call to `encodeWithdrawTRC10`
    ///
    /// Solidity function: `function encodeWithdrawTRC10(uint tokenID, uint tokenCount) public returns (bool success);`
    public static func encodeWithdrawTRC10(tokenId: BigUInt, tokens: BigUInt) -> Data {
        let function = Function(name: "withdrawTRC10", parameters: [.uint(bits: 256), .uint(bits: 256)])
        let encoder = ABIEncoder()
        try! encoder.encode(function: function, arguments: [tokenId, tokens])
        return encoder.data
    }
    
    /// Encodes a function call to `encodeWithdrawTRC20`
    ///
    /// Solidity function: `function encodeWithdrawTRC20(uint tokenCount) public returns (bool success);`
    public static func encodeWithdrawTRC20(tokens: BigUInt) -> Data {
        let function = Function(name: "withdrawal", parameters: [.uint(bits: 256)])
        let encoder = ABIEncoder()
        try! encoder.encode(function: function, arguments: [tokens])
        return encoder.data
    }
    
    /// Encodes a function call to `encodeGetExchangeBalance`
    ///
    /// Solidity function: `function getBalance(address contractOwner, array[address] tokens) public returns (array);`
    public static func encodeExchangeBalance(contractOwner: Address, tokens: [Address]) -> Data {
        let function = Function(name: "getBalance", parameters: [.address, .dynamicArray(.address)])
        let encoder = ABIEncoder()
        try! encoder.encode(function: function, arguments: [contractOwner, tokens])
        return encoder.data
    }
    
    /// Encodes a function call to `trxToTokenSwapInput`
    ///
    /// Solidity function: `function trxToTokenSwapInput(uint256 min_tokens, uint256 deadline) public returns (uint256);`
    public static func encodetTrxToTokenSwapInput(minTokens: BigUInt, deadline: BigUInt) -> Data {
        let function = Function(name: "trxToTokenSwapInput", parameters: [.uint(bits: 256), .uint(bits: 256)])
        let encoder = ABIEncoder()
        try! encoder.encode(function: function, arguments: [minTokens, deadline])
        return encoder.data
    }
    
    /// Encodes a function call to `trxToTokenSwapOutput`
    ///
    /// Solidity function: `function trxToTokenSwapOutput(uint256 tokensBought, uint256 deadline) public returns (uint256);`
    public static func encodetTrxToTokenSwapOutput(tokensBought: BigUInt, deadline: BigUInt) -> Data {
        let function = Function(name: "trxToTokenSwapOutput", parameters: [.uint(bits: 256), .uint(bits: 256)])
        let encoder = ABIEncoder()
        try! encoder.encode(function: function, arguments: [tokensBought, deadline])
        return encoder.data
    }
    
    
    /// Encodes a function call to `tokenToTrxSwapInput`
    ///
    /// Solidity function: `function tokenToTrxSwapInput(uint256 tokens_sold, uint256 min_trx, uint256 deadline) external returns (uint256);`
    public static func encodeTokenToTrxSwapInput(tokensSold: BigUInt, minTrx: BigUInt, deadline: BigUInt) -> Data {
        let function = Function(name: "tokenToTrxSwapInput", parameters: [.uint(bits: 256), .uint(bits: 256), .uint(bits: 256)])
        let encoder = ABIEncoder()
        try! encoder.encode(function: function, arguments: [tokensSold, minTrx, deadline])
        return encoder.data
    }
    
    /// Encodes a function call to `tokenToTrxSwapOutput`
    ///
    /// Solidity function: `function function tokenToTrxSwapOutput(uint256 trx_bought, uint256 max_tokens, uint256 deadline) external returns (uint256);`
    public static func encodeTokenToTrxSwapOutput(trxBought: BigUInt, maxTokens: BigUInt, deadline: BigUInt) -> Data {
        let function = Function(name: "tokenToTrxSwapOutput", parameters: [.uint(bits: 256), .uint(bits: 256), .uint(bits: 256)])
        let encoder = ABIEncoder()
        try! encoder.encode(function: function, arguments: [trxBought, maxTokens, deadline])
        return encoder.data
    }
    
    /// Encodes a function call to `tokenToTokenSwapInput`
    ///
    /// Solidity function: `function tokenToTokenSwapInput(uint256 tokens_sold, uint256 min_tokens_bought, uint256 min_trx_bought, uint256 deadline, address token_addr) external returns (uint256);`
    public static func encodeTokenToTokenSwapInput(tokensSold: BigUInt, minTokensBought: BigUInt, minTrxBought: BigUInt, deadline: BigUInt, tokenAddr: Address) -> Data {
        let function = Function(name: "tokenToTokenSwapInput", parameters: [.uint(bits: 256), .uint(bits: 256), .uint(bits: 256), .uint(bits: 256), .address])
        let encoder = ABIEncoder()
        try! encoder.encode(function: function, arguments: [tokensSold, minTokensBought, minTrxBought, deadline, tokenAddr])
        return encoder.data
    }
    
    /// Encodes a function call to `tokenToTrxSwapOutput`
    ///
    /// Solidity function: `function tokenToTokenSwapOutput(uint256 tokens_bought, uint256 max_tokens_sold, uint256 max_trx_sold, uint256 deadline, address token_addr) external returns (uint256);`
    public static func encodeTokenToTokenSwapOutput(tokensBought: BigUInt, maxTokensSold: BigUInt, maxTrxSold: BigUInt, deadline: BigUInt, tokenAddr: Address) -> Data {
        let function = Function(name: "tokenToTokenSwapOutput", parameters: [.uint(bits: 256), .uint(bits: 256), .uint(bits: 256), .uint(bits: 256), .address])
        let encoder = ABIEncoder()
        try! encoder.encode(function: function, arguments: [tokensBought, maxTokensSold, maxTrxSold, deadline, tokenAddr])
        return encoder.data
    }
    
    /// Encodes a function call to `queryDIDAddress`
    ///
    /// Solidity function: `function queryDIDAddress(String did) public returns (address);`
    public static func encodeQueryDIDAddress(did: String) -> Data {
        let function = Function(name: "queryAddress", parameters: [.string])
        let encoder = ABIEncoder()
        try! encoder.encode(function: function, arguments: [did])
        return encoder.data
    }
    
    /// Swap V3
    public static func encodeSwapExactInput(path: [Address],
                                            poolVersion: [String],
                                            versionLen: [BigUInt],
                                            fees: [BigUInt],
                                            tuple: [Any]) -> Data {
        let function = Function(name: "swapExactInput", parameters: [.dynamicArray(.address),
                                                                     .dynamicArray(.string),
                                                                     .dynamicArray(.uint(bits: 256)),
                                                                     .dynamicArray(.uint(bits: 24)),
                                                                     .tuple([.uint(bits: 256), .uint(bits: 256), .address, .uint(bits: 256)])])
        let encoder = ABIEncoder()
        try! encoder.encode(function: function, arguments: [path, poolVersion, versionLen, fees, tuple])
        return encoder.data
    }
}
