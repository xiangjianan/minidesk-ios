import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Export the layered glass artwork to an opaque 1024px iOS app icon.
let sourceURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .appendingPathComponent("assets/minidesk-flat-glass-source.png")
let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil)!
let image = CGImageSourceCreateImageAtIndex(source, 0, nil)!
// Align the colored disc, excluding its white surround and faint shadow.
let scan = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
    bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
scan.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
let pixels = scan.data!.assumingMemoryBound(to: UInt8.self)
var minX = image.width, maxX = 0, minY = image.height, maxY = 0
for y in 0..<image.height {
    for x in 0..<image.width {
        let offset = (y * image.width + x) * 4
        let high = max(pixels[offset], pixels[offset + 1], pixels[offset + 2])
        let low = min(pixels[offset], pixels[offset + 1], pixels[offset + 2])
        if Int(high) - Int(low) > 80 && high > 150 {
            minX = min(minX, x); maxX = max(maxX, x)
            minY = min(minY, y); maxY = max(maxY, y)
        }
    }
}
precondition(minX <= maxX && minY <= maxY)
let scale = 1024 / CGFloat(image.width)
let dx = (CGFloat(image.width - 1) / 2 - CGFloat(minX + maxX) / 2) * scale
let dy = (CGFloat(image.height - 1) / 2 - CGFloat(minY + maxY) / 2) * scale
let context = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8,
    bytesPerRow: 1024 * 4, space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
context.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
context.interpolationQuality = .high
context.draw(image, in: CGRect(x: dx, y: -dy, width: 1024, height: 1024))
let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: CommandLine.arguments[1]) as CFURL,
    UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, context.makeImage()!, nil)
precondition(CGImageDestinationFinalize(destination))
