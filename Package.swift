// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Dougie",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Dougie", targets: ["Dougie"])],
    targets: [
        .target(name: "DougieCore"),
        .executableTarget(
            name: "Dougie", dependencies: ["DougieCore"],
            resources: [.copy("Assets/lludix-cup.png")]
        ),
        .testTarget(name: "DougieCoreTests", dependencies: ["DougieCore"])
    ]
)
