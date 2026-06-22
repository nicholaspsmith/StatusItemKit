// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "StatusItemKit",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "StatusItemKit", targets: ["StatusItemKit"]),
        .executable(name: "StatusItemKitDemo", targets: ["StatusItemKitDemo"]),
    ],
    targets: [
        .target(name: "StatusItemKit"),
        .executableTarget(name: "StatusItemKitDemo", dependencies: ["StatusItemKit"]),
        .testTarget(name: "StatusItemKitTests", dependencies: ["StatusItemKit"]),
    ]
)
