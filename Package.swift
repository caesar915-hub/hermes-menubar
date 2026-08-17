// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HermesMenuBar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "HermesMenuBar",
            targets: ["HermesMenuBar"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "HermesMenuBar",
            dependencies: [],
            path: "Sources/HermesMenuBar"
        )
    ]
)
