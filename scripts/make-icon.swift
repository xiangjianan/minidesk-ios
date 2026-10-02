import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Export the midnight artwork to an opaque 1024px iOS app icon.
let sourceURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .appendingPathComponent("assets/minidesk-midnight-source.png")
let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil)!
let image = CGImageSourceCreateImageAtIndex(source, 0, nil)!
let context = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8,
    bytesPerRow: 1024 * 4, space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
context.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
context.interpolationQuality = .high
context.draw(image, in: CGRect(x: 0, y: 0, width: 1024, height: 1024))
let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: CommandLine.arguments[1]) as CFURL,
    UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, context.makeImage()!, nil)
precondition(CGImageDestinationFinalize(destination))
