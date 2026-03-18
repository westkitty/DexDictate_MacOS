import Foundation

public struct WatermarkAsset: Identifiable, Equatable {
    public let filename: String
    public let url: URL

    public var id: String { filename }
}

@MainActor
public final class WatermarkAssetProvider: ObservableObject {
    @Published public private(set) var currentAsset: WatermarkAsset?

    private var lastSelectedFilenameByProfile: [AppProfile: String] = [:]

    public init() {}

    public func assets(for profile: AppProfile) -> [WatermarkAsset] {
        Self.filenames(for: profile).compactMap { filename in
            let resourceName = URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent
            let resourceExtension = URL(fileURLWithPath: filename).pathExtension
            guard let url = Safety.resourceBundle.url(forResource: resourceName, withExtension: resourceExtension.isEmpty ? nil : resourceExtension) else {
                return nil
            }

            return WatermarkAsset(filename: filename, url: url)
        }
    }

    @discardableResult
    public func selectRandomAsset(for profile: AppProfile) -> WatermarkAsset? {
        let pool = assets(for: profile)
        guard !pool.isEmpty else {
            currentAsset = nil
            return nil
        }

        let lastFilename = lastSelectedFilenameByProfile[profile]
        let nonRepeatingPool = pool.filter { $0.filename != lastFilename }
        let selectionPool = nonRepeatingPool.isEmpty ? pool : nonRepeatingPool
        let asset = selectionPool.randomElement() ?? pool[0]

        currentAsset = asset
        lastSelectedFilenameByProfile[profile] = asset.filename
        return asset
    }

    public static func filenames(for profile: AppProfile) -> [String] {
        switch profile {
        case .standard:
            return [
                "dexdictate-icon-standard-01.png",
                "dexdictate-icon-standard-02.png",
                "dexdictate-icon-standard-03.png",
                "dexdictate-icon-standard-04.png",
                "dexdictate-icon-standard-05.png",
                "dexdictate-icon-standard-06.png",
                "dexdictate-icon-standard-07.png",
                "dexdictate-icon-standard-08.png",
                "dexdictate-icon-standard-09.png",
                "dexdictate-icon-standard-10.png",
                "dexdictate-icon-standard-11.png"
            ]
        case .canadian:
            return [
                "dexdictate-icon-canada-01.png",
                "dexdictate-icon-canada-02.png",
                "dexdictate-icon-canada-03.png",
                "dexdictate-icon-canada-04.png",
                "dexdictate-icon-canada-05.png"
            ]
        case .aussie:
            return [
                "dexdictate-icon-aussie-01.png",
                "dexdictate-icon-aussie-02.png"
            ]
        }
    }
}
