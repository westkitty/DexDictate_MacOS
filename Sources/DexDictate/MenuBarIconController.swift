import AppKit
import DexDictateKit

@MainActor
final class MenuBarIconController: ObservableObject {
    struct IconAsset: Identifiable, Equatable {
        let id: String
        let url: URL

        var displayName: String {
            url.deletingPathExtension().lastPathComponent
        }
    }

    static let shared = MenuBarIconController()

    @Published private(set) var icons: [IconAsset] = []
    let assetDirectoryURL = URL(fileURLWithPath: "/Users/andrew/Documents/ui assets", isDirectory: true)

    private let fileManager: FileManager
    private var sourceCache: [String: NSImage] = [:]
    private var previewCache: [String: NSImage] = [:]
    private var menuBarCache: [String: NSImage] = [:]
    private var appLogoPreviewCache: NSImage?
    private var appLogoMenuBarCache: NSImage?

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        refreshAssets()
    }

    func refreshAssets() {
        let discoveredIcons = loadIcons()
        if discoveredIcons != icons {
            sourceCache.removeAll()
            previewCache.removeAll()
            menuBarCache.removeAll()
            appLogoPreviewCache = nil
            appLogoMenuBarCache = nil
            icons = discoveredIcons
        }
    }

    func selectedIcon(using settings: AppSettings) -> IconAsset? {
        guard !settings.selectedMenuBarIconIdentifier.isEmpty else {
            return nil
        }

        return icons.first { $0.id == settings.selectedMenuBarIconIdentifier }
    }

    func previewImage(for icon: IconAsset) -> NSImage? {
        if let cached = previewCache[icon.id] {
            return cached
        }

        guard let image = preparedImage(for: icon, canvasSize: 42, markAsTemplate: false) else {
            return nil
        }

        previewCache[icon.id] = image
        return image
    }

    func menuBarImage(for icon: IconAsset) -> NSImage? {
        if let cached = menuBarCache[icon.id] {
            return cached
        }

        guard let image = preparedImage(for: icon, canvasSize: 20, markAsTemplate: true) else {
            return nil
        }

        menuBarCache[icon.id] = image
        return image
    }

    func appLogoPreviewImage() -> NSImage? {
        if let cached = appLogoPreviewCache {
            return cached
        }

        guard let image = preparedAppLogo(canvasSize: 42, markAsTemplate: false) else {
            return nil
        }

        appLogoPreviewCache = image
        return image
    }

    func appLogoMenuBarImage() -> NSImage? {
        if let cached = appLogoMenuBarCache {
            return cached
        }

        guard let image = preparedAppLogo(canvasSize: 20, markAsTemplate: true) else {
            return nil
        }

        appLogoMenuBarCache = image
        return image
    }

    private func loadIcons() -> [IconAsset] {
        guard let fileURLs = try? fileManager.contentsOfDirectory(
            at: assetDirectoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let supportedExtensions = Set(["png", "pdf", "jpg", "jpeg"])

        return fileURLs
            .filter { supportedExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            .map { url in
                IconAsset(id: url.lastPathComponent, url: url)
            }
    }

    private func sourceImage(for icon: IconAsset) -> NSImage? {
        if let cached = sourceCache[icon.id] {
            return cached
        }

        guard let image = NSImage(contentsOf: icon.url) else {
            return nil
        }

        sourceCache[icon.id] = image
        return image
    }

    private func preparedImage(for icon: IconAsset, canvasSize: CGFloat, markAsTemplate: Bool) -> NSImage? {
        guard
            let sourceImage = sourceImage(for: icon),
            let image = preparedImage(from: sourceImage, canvasSize: canvasSize, markAsTemplate: markAsTemplate)
        else {
            return nil
        }

        return image
    }

    private func preparedAppLogo(canvasSize: CGFloat, markAsTemplate: Bool) -> NSImage? {
        guard
            let logoURL = Safety.resourceBundle.url(
                forResource: "Assets.xcassets/dog_background.imageset/DexDictateMacOS_Icon",
                withExtension: "png"
            ),
            let logoImage = NSImage(contentsOf: logoURL)
        else {
            return nil
        }

        return preparedImage(
            from: logoImage,
            canvasSize: canvasSize,
            markAsTemplate: markAsTemplate,
            normalizedFocusRect: CGRect(x: 0.14, y: 0.10, width: 0.70, height: 0.72)
        )
    }

    private func preparedImage(
        from sourceImage: NSImage,
        canvasSize: CGFloat,
        markAsTemplate: Bool,
        normalizedFocusRect: CGRect? = nil
    ) -> NSImage? {
        guard
            let raster = rasterizedBitmap(from: sourceImage, pixelSide: 256),
            let preparedMask = thresholdedMask(
                from: raster,
                threshold: markAsTemplate ? 0.60 : 0.50,
                feather: markAsTemplate ? 0.06 : 0.16,
                normalizedFocusRect: normalizedFocusRect
            )
        else {
            return nil
        }

        return render(
            maskImage: preparedMask.image,
            sourceBounds: preparedMask.bounds,
            canvasSize: canvasSize,
            markAsTemplate: markAsTemplate
        )
    }

    private func rasterizedBitmap(from image: NSImage, pixelSide: Int) -> NSBitmapImageRep? {
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelSide,
            pixelsHigh: pixelSide,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return nil
        }

        bitmap.size = NSSize(width: pixelSide, height: pixelSide)

        NSGraphicsContext.saveGraphicsState()
        guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            NSGraphicsContext.restoreGraphicsState()
            return nil
        }

        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        NSColor.clear.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: pixelSide, height: pixelSide)).fill()

        let fitRect = aspectFitRect(for: image.size, in: NSRect(x: 0, y: 0, width: pixelSide, height: pixelSide))
        image.draw(
            in: fitRect,
            from: NSRect(origin: .zero, size: image.size),
            operation: .sourceOver,
            fraction: 1
        )
        NSGraphicsContext.restoreGraphicsState()
        return bitmap
    }

    private func thresholdedMask(
        from raster: NSBitmapImageRep,
        threshold: CGFloat,
        feather: CGFloat,
        normalizedFocusRect: CGRect? = nil
    ) -> (image: NSImage, bounds: NSRect)? {
        guard
            let sourceData = raster.bitmapData,
            let mask = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: raster.pixelsWide,
                pixelsHigh: raster.pixelsHigh,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            ),
            let maskData = mask.bitmapData
        else {
            return nil
        }

        let bytesPerPixel = 4
        let pixelCount = raster.pixelsWide * raster.pixelsHigh

        for index in 0..<pixelCount {
            let offset = index * bytesPerPixel
            let red = CGFloat(sourceData[offset]) / 255
            let green = CGFloat(sourceData[offset + 1]) / 255
            let blue = CGFloat(sourceData[offset + 2]) / 255
            let alpha = CGFloat(sourceData[offset + 3]) / 255

            let luminance = (0.2126 * red) + (0.7152 * green) + (0.0722 * blue)
            let darkness = (1 - luminance) * alpha
            let normalized = max(0, min(1, (darkness - threshold) / feather))
            let ink = UInt8((normalized * 255).rounded())

            maskData[offset] = 0
            maskData[offset + 1] = 0
            maskData[offset + 2] = 0
            maskData[offset + 3] = ink
        }

        let focusBounds = normalizedFocusRect.map { focusRect in
            NSRect(
                x: floor(focusRect.origin.x * CGFloat(raster.pixelsWide)),
                y: floor(focusRect.origin.y * CGFloat(raster.pixelsHigh)),
                width: ceil(focusRect.size.width * CGFloat(raster.pixelsWide)),
                height: ceil(focusRect.size.height * CGFloat(raster.pixelsHigh))
            )
        }

        guard let bounds = visibleBounds(of: mask, limitingTo: focusBounds) ?? visibleBounds(of: mask) else {
            return nil
        }

        let result = NSImage(size: NSSize(width: raster.pixelsWide, height: raster.pixelsHigh))
        result.addRepresentation(mask)
        return (result, bounds)
    }

    private func visibleBounds(of raster: NSBitmapImageRep, limitingTo limitRect: NSRect? = nil) -> NSRect? {
        guard let data = raster.bitmapData else {
            return nil
        }

        let bytesPerPixel = 4
        let alphaThreshold: UInt8 = 18
        var minX = raster.pixelsWide
        var minY = raster.pixelsHigh
        var maxX = -1
        var maxY = -1

        let xRange: Range<Int>
        let yRange: Range<Int>

        if let limitRect {
            let minLimitX = max(0, Int(floor(limitRect.minX)))
            let maxLimitX = min(raster.pixelsWide, Int(ceil(limitRect.maxX)))
            let minLimitY = max(0, Int(floor(limitRect.minY)))
            let maxLimitY = min(raster.pixelsHigh, Int(ceil(limitRect.maxY)))

            guard minLimitX < maxLimitX, minLimitY < maxLimitY else {
                return nil
            }

            xRange = minLimitX..<maxLimitX
            yRange = minLimitY..<maxLimitY
        } else {
            xRange = 0..<raster.pixelsWide
            yRange = 0..<raster.pixelsHigh
        }

        for y in yRange {
            for x in xRange {
                let offset = ((y * raster.pixelsWide) + x) * bytesPerPixel
                let alpha = data[offset + 3]
                if alpha > alphaThreshold {
                    minX = min(minX, x)
                    minY = min(minY, y)
                    maxX = max(maxX, x)
                    maxY = max(maxY, y)
                }
            }
        }

        guard maxX >= minX, maxY >= minY else {
            return nil
        }

        return NSRect(
            x: minX,
            y: minY,
            width: (maxX - minX) + 1,
            height: (maxY - minY) + 1
        )
    }

    private func render(maskImage: NSImage, sourceBounds: NSRect?, canvasSize: CGFloat, markAsTemplate: Bool) -> NSImage? {
        let logicalSize = NSSize(width: canvasSize, height: canvasSize)
        let output = NSImage(size: logicalSize)

        output.lockFocus()
        defer { output.unlockFocus() }

        guard let bounds = sourceBounds, bounds.width > 0, bounds.height > 0 else {
            return nil
        }

        NSColor.clear.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: logicalSize)).fill()
        NSGraphicsContext.current?.imageInterpolation = .high

        let contentInset = markAsTemplate ? max(0.75, canvasSize * 0.05) : max(2, canvasSize * 0.12)
        let availableWidth = max(1, canvasSize - (contentInset * 2))
        let availableHeight = max(1, canvasSize - (contentInset * 2))
        let scale = min(availableWidth / bounds.width, availableHeight / bounds.height)
        let drawSize = NSSize(width: bounds.width * scale, height: bounds.height * scale)
        let drawRect = NSRect(
            x: (canvasSize - drawSize.width) / 2,
            y: (canvasSize - drawSize.height) / 2,
            width: drawSize.width,
            height: drawSize.height
        )

        maskImage.draw(
            in: drawRect,
            from: bounds,
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: false,
            hints: [.interpolation: NSImageInterpolation.high]
        )

        output.isTemplate = markAsTemplate
        return output
    }

    private func aspectFitRect(for sourceSize: NSSize, in destinationRect: NSRect) -> NSRect {
        guard sourceSize.width > 0, sourceSize.height > 0 else {
            return destinationRect
        }

        let scale = min(destinationRect.width / sourceSize.width, destinationRect.height / sourceSize.height)
        let fittedSize = NSSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
        return NSRect(
            x: destinationRect.midX - (fittedSize.width / 2),
            y: destinationRect.midY - (fittedSize.height / 2),
            width: fittedSize.width,
            height: fittedSize.height
        )
    }
}
