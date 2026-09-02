import Foundation
import XCTest
@testable import TLCore

final class Secp256k1PerformanceTests: XCTestCase {
    func testFixedVectorSigningPerformanceEnvelope() throws {
        let key = TLCore.PrivateKey(Data(repeating: 0, count: 31) + Data([1]))
        let hash = Data(repeating: 0x11, count: 32)
        let expected = "e7c93726a865578504442b1a6827f676e0ed74bdff2be3960d1e253bbcfc44626aa772b878bc912bdbb33a0014ec507c4b3896ea85aa914b74dee9b7ac3e56da01"

        for _ in 0..<300 {
            XCTAssertEqual(try key.sign(hash: hash).data.hex, expected)
        }

        var durations = [TimeInterval]()
        durations.reserveCapacity(1_000)
        let processInfo = ProcessInfo.processInfo
        let totalStart = processInfo.systemUptime
        for _ in 0..<1_000 {
            let start = processInfo.systemUptime
            let signature = try key.sign(hash: hash)
            durations.append(processInfo.systemUptime - start)
            XCTAssertFalse(signature.data.isEmpty)
            XCTAssertEqual(signature.data.hex, expected)
            XCTAssertEqual(signature.v, 1)
        }
        let total = processInfo.systemUptime - totalStart
        durations.sort()
        let medianMicroseconds = durations[durations.count / 2] * 1_000_000
        let p95Microseconds = durations[Int(Double(durations.count - 1) * 0.95)] * 1_000_000
        print("Trezor sign median=\(medianMicroseconds)us p95=\(p95Microseconds)us")
        XCTAssertLessThan(total, 5.0)
    }
}
