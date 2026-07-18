import AppKit

public enum ArtworkColorExtractor {
    public static func palette(from data: Data, count: Int = 7) -> [NSColor] {
        guard count > 0 else { return [] }

        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return []
        }

        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return [] }

        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return []
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
        guard let buffer = context.data else { return [] }

        var buckets: [Int: Int] = [:]
        let step = max(1, min(8, width / 16))

        for y in stride(from: 0, to: height, by: step) {
            for x in stride(from: 0, to: width, by: step) {
                let offset = (y * bytesPerRow) + (x * bytesPerPixel)
                let red = buffer.load(fromByteOffset: offset, as: UInt8.self)
                let green = buffer.load(fromByteOffset: offset + 1, as: UInt8.self)
                let blue = buffer.load(fromByteOffset: offset + 2, as: UInt8.self)
                let alpha = buffer.load(fromByteOffset: offset + 3, as: UInt8.self)

                guard alpha > 0 else { continue }

                let bucketKey = ((Int(red) / 64) << 4) | ((Int(green) / 64) << 2) | (Int(blue) / 64)
                buckets[bucketKey, default: 0] += 1
            }
        }

        let sortedBuckets = buckets.sorted { $0.value > $1.value }
        var colors: [NSColor] = []

        for (index, bucketEntry) in sortedBuckets.prefix(count).enumerated() {
            let bucket = bucketEntry.key
            let red = Double((bucket >> 4) & 0x3) * 64.0 + 32.0
            let green = Double((bucket >> 2) & 0x3) * 64.0 + 32.0
            let blue = Double(bucket & 0x3) * 64.0 + 32.0

            let baseColor = NSColor(deviceRed: red / 255.0, green: green / 255.0, blue: blue / 255.0, alpha: 1.0)
            let adjustedColor = index % 2 == 0
                ? baseColor.blended(withFraction: 0.25, of: .white) ?? baseColor
                : baseColor.blended(withFraction: 0.15, of: .black) ?? baseColor
            colors.append(adjustedColor)
        }

        return colors.isEmpty ? [NSColor.systemBlue] : colors
    }
}
