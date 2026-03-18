import Foundation

@MainActor
public final class FlavorTickerManager: ObservableObject {
    @Published public private(set) var currentLine: FlavorLine?

    private var recentLineIDsByProfile: [AppProfile: [String]] = [:]

    public init() {}

    @discardableResult
    public func selectNextLine(from pack: [FlavorLine], for profile: AppProfile) -> FlavorLine? {
        guard !pack.isEmpty else {
            currentLine = nil
            return nil
        }

        let recentIDs = recentLineIDsByProfile[profile, default: []]
        let immediateLastID = recentIDs.last
        let recentAvoidance = Set(recentIDs.suffix(5))

        let nonImmediate = pack.filter { $0.id != immediateLastID }
        let preferred = nonImmediate.filter { !recentAvoidance.contains($0.id) }

        let selectionPool: [FlavorLine]
        if !preferred.isEmpty {
            selectionPool = preferred
        } else if !nonImmediate.isEmpty {
            selectionPool = nonImmediate
        } else {
            selectionPool = pack
        }

        let nextLine = selectionPool.randomElement() ?? pack[0]
        currentLine = nextLine
        recordSelection(nextLine, for: profile)
        return nextLine
    }

    public func clearCurrentLine() {
        currentLine = nil
    }

    private func recordSelection(_ line: FlavorLine, for profile: AppProfile) {
        var recentIDs = recentLineIDsByProfile[profile, default: []]
        recentIDs.append(line.id)
        if recentIDs.count > 5 {
            recentIDs.removeFirst(recentIDs.count - 5)
        }
        recentLineIDsByProfile[profile] = recentIDs
    }
}
