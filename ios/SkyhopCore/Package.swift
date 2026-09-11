// swift-tools-version:5.9
import PackageDescription

// The game engine is a plain Swift package with no UIKit/SwiftUI imports,
// so `swift test` runs it on macOS, Linux and CI in a couple of seconds.
let package = Package(
    name: "SkyhopCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SkyhopCore", targets: ["SkyhopCore"]),
    ],
    targets: [
        .target(name: "SkyhopCore"),
        .testTarget(name: "SkyhopCoreTests", dependencies: ["SkyhopCore"]),
    ]
)
