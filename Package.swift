// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DualTyper",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "DualTyperCore", targets: ["DualTyperCore"])
    ],
    targets: [
        .target(name: "DualTyperCore"),
        .testTarget(
            name: "DualTyperCoreTests",
            dependencies: ["DualTyperCore"]
        )
    ]
)
