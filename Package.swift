// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "MiniDeskCore", platforms: [.macOS(.v14)], products: [.library(name: "MiniDeskCore", targets: ["MiniDeskCore"])], targets: [.target(name: "MiniDeskCore", path: "MiniDesk/Core"), .testTarget(name: "MiniDeskCoreTests", dependencies: ["MiniDeskCore"], path: "Tests/MiniDeskCoreTests")])
