import AppKit
let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSColor(calibratedRed: 0.90, green: 0.94, blue: 1.0, alpha: 1).setFill()
NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
let gradient = NSGradient(starting: NSColor(calibratedRed: 0.08, green: 0.55, blue: 1.0, alpha: 1), ending: NSColor(calibratedRed: 0.0, green: 0.30, blue: 0.85, alpha: 1))!
gradient.draw(in: NSBezierPath(roundedRect: NSRect(x: 165,y: 175,width: 694,height: 694), xRadius: 160, yRadius: 160), angle: -50)
NSColor.white.withAlphaComponent(0.92).setFill()
NSBezierPath(roundedRect: NSRect(x: 288,y: 350,width: 448,height: 60), xRadius: 30,yRadius: 30).fill()
NSBezierPath(roundedRect: NSRect(x: 318,y: 225,width: 42,height: 150), xRadius: 21,yRadius: 21).fill()
NSBezierPath(roundedRect: NSRect(x: 664,y: 225,width: 42,height: 150), xRadius: 21,yRadius: 21).fill()
NSBezierPath(roundedRect: NSRect(x: 350,y: 440,width: 324,height: 272), xRadius: 46,yRadius: 46).fill()
NSColor(calibratedRed: 0.0,green: 0.478,blue: 1.0,alpha: 1).setStroke()
let tick = NSBezierPath(); tick.lineWidth = 27; tick.lineCapStyle = .round; tick.lineJoinStyle = .round
tick.move(to: NSPoint(x: 431,y: 569)); tick.line(to: NSPoint(x: 489,y: 514)); tick.line(to: NSPoint(x: 592,y: 629)); tick.stroke()
NSGraphicsContext.restoreGraphicsState()
let bitmap = rep
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
