
import Foundation

extension Array {
    /// Splits the array into chunks. Nonpositive sizes return an empty array.
    /// - Parameter chunkSize: Size of each subarray
    public func split(intoChunksOf chunkSize: Int) -> [[Element]] {
        guard chunkSize > 0 else { return [] }
        var chunks = [[Element]]()
        var start = 0
        while start < count {
            let end = start + Swift.min(chunkSize, count - start)
            chunks.append(Array(self[start..<end]))
            start = end
        }
        return chunks
    }
    func safe(_ index: Int) -> Element? {
        guard (0..<count).contains(index) else { return nil }
        return self[index]
    }
}

