// swift-tools-version: 5.9
// This is a Skip (https://skip.tools) package,
// containing a Swift Package Manager project
// that will use the Skip build plugin to transpile the
// Swift Package, Sources, and Tests into an
// Android Gradle Project with Kotlin sources and JUnit tests.
import PackageDescription

let package = Package(
    name: "my-sku",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .macOS(.v14), .tvOS(.v17), .watchOS(.v10), .macCatalyst(.v17)],
    products: [
        .library(name: "MySkuApp", type: .dynamic, targets: ["MySku"]),
    ],
    dependencies: [
        .package(url: "https://source.skip.tools/skip.git", from: "1.2.24"),
        .package(url: "https://source.skip.tools/skip-ui.git", from: "1.0.0")
    ],
    targets: [
        .target(name: "MySku", dependencies: [
            .product(name: "SkipUI", package: "skip-ui")
        ], resources: [.process("Resources")], plugins: [.plugin(name: "skipstone", package: "skip")]),
        .testTarget(name: "MySkuTests", dependencies: [
            "MySku",
            .product(name: "SkipTest", package: "skip")
        ], resources: [.process("Resources")], plugins: [.plugin(name: "skipstone", package: "skip")]),
    ]
)
