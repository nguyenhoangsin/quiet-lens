// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "QuietLens",
    platforms: [.macOS("26.0")],
    products: [.executable(name: "QuietLens", targets: ["QuietLens"])],
    targets: [
        .executableTarget(name: "QuietLens", resources: [.process("Resources")]),
        .testTarget(name: "QuietLensTests", dependencies: ["QuietLens"]),
    ]
)
