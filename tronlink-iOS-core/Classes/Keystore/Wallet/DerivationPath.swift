
import Foundation

/// Represents a hierarchical determinisic derivation path.
public struct DerivationPath: Hashable, CustomStringConvertible {
    /// List of indices in the derivation path.
    public private(set) var indices = [Index]()

    init(indices: [Index]) {
        self.indices = indices
    }

    /// Accepts an absolute or relative path. Only an explicit `m` denotes the root.
    public init?(_ string: String) {
        guard !DerivationPath.hasEmptyComponent(string) else { return nil }
        let components = string.split(separator: "/")
        for component in components.dropFirst(components.first == "m" ? 1 : 0) {
            if component.hasSuffix("'") {
                guard let index = Int(component.dropLast()), UInt32(exactly: index) != nil else {
                    return nil
                }
                indices.append(Index(index, hardened: true))
            } else {
                guard let index = Int(component), UInt32(exactly: index) != nil else {
                    return nil
                }
                indices.append(Index(index, hardened: false))
            }
        }
    }

    /// Older files skipped empty components and misplaced root markers. Keep the other
    /// components verbatim, including index templates and historical hardened values.
    static func restoringStoredPath(_ path: String) -> String {
        let components = path.split(separator: "/")
        guard hasEmptyComponent(path) || components.dropFirst().contains("m") else { return path }
        let children = components.filter { $0 != "m" }
        return children.isEmpty ? "m" : "m/" + children.joined(separator: "/")
    }

    private static func hasEmptyComponent(_ path: String) -> Bool {
        return path.isEmpty || path.hasPrefix("/") || path.hasSuffix("/") || path.contains("//")
    }

    /// Increments the last index of the derivation path.
    public mutating func increment() {
        guard var last = indices.last else {
            preconditionFailure("Can't increment empty derivation path")
        }
        last.value += 1

        indices.removeLast()
        indices.append(last)
    }

    /// Returns a new derivation path with an increased last index.
    public func incremented() -> DerivationPath {
        guard var last = indices.last else {
            preconditionFailure("Can't increment empty derivation path")
        }
        last.value += 1

        var newIndices = indices
        newIndices.removeLast()
        newIndices.append(last)
        return DerivationPath(indices: newIndices)
    }

    /// String representation.
    public var description: String {
        return indices.isEmpty ? "m" : "m/" + indices.map({ $0.description }).joined(separator: "/")
    }

    public var hashValue: Int {
        return indices.reduce(0, { $0 ^ $1.hashValue })
    }

    public static func == (lhs: DerivationPath, rhs: DerivationPath) -> Bool {
        return lhs.indices == rhs.indices
    }
}
