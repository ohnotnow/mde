// swift-tools-version:5.9
import PackageDescription

// SwiftPM build for MDE — lets the app be built with only the Xcode
// Command Line Tools (no full Xcode install). The .app bundle itself is
// assembled by build.sh; this manifest just compiles the executable and
// resolves the two dependencies (matching MDE.xcodeproj's Package.resolved).
let package = Package(
    name: "MDE",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-cmark", .upToNextMinor(from: "0.7.1")),
        .package(url: "https://github.com/migueldeicaza/SwiftTerm", .upToNextMajor(from: "1.13.0")),
    ],
    targets: [
        .executableTarget(
            name: "MDE",
            dependencies: [
                .product(name: "cmark-gfm", package: "swift-cmark"),
                .product(name: "cmark-gfm-extensions", package: "swift-cmark"),
                .product(name: "SwiftTerm", package: "SwiftTerm"),
            ],
            path: "MDE/MDE",
            exclude: [
                "Info.plist",
                "MDE.entitlements",
                "Assets.xcassets",
            ]
        )
    ]
)
