import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Exact PWA artwork, enlarged with nearest-neighbor sampling to preserve pixels.
let sourceURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .appendingPathComponent("assets/mini-desk-pwa-icon-512.png")
let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil)!
let image = CGImageSourceCreateImageAtIndex(source, 0, nil)!
let context = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8,
    bytesPerRow: 1024 * 4, space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
context.interpolationQuality = .none
context.draw(image, in: CGRect(x: 0, y: 0, width: 1024, height: 1024))
let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: CommandLine.arguments[1]) as CFURL,
    UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, context.makeImage()!, nil)
precondition(CGImageDestinationFinalize(destination))
