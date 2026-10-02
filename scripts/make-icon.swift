import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Use the same Apple SF Symbol as the paired desktop screen.
let configuration = NSImage.SymbolConfiguration(pointSize: 640, weight: .regular)
    .applying(NSImage.SymbolConfiguration(hierarchicalColor: NSColor(calibratedRed: 0, green: 122 / 255, blue: 1, alpha: 1)))
let symbol = NSImage(systemSymbolName: "desktopcomputer", accessibilityDescription: nil)!
    .withSymbolConfiguration(configuration)!
var proposedRect = CGRect(origin: .zero, size: symbol.size)
let image = symbol.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil)!
let context = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8,
    bytesPerRow: 1024 * 4, space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
context.setFillColor(CGColor(red: 0.94, green: 0.97, blue: 1, alpha: 1))
context.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
let width: CGFloat = 680
let height = width * CGFloat(image.height) / CGFloat(image.width)
context.interpolationQuality = .high
context.draw(image, in: CGRect(x: (1024 - width) / 2, y: (1024 - height) / 2, width: width, height: height))
let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: CommandLine.arguments[1]) as CFURL,
    UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, context.makeImage()!, nil)
precondition(CGImageDestinationFinalize(destination))
