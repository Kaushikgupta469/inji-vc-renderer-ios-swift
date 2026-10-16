// swift-tools-version: 5.7.0
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "InjiVcRenderer",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "InjiVcRenderer",
            targets: ["InjiVcRenderer"]),
    ],
    dependencies: [
        .package(url: "https://github.com/inji/pixelpass-ios-swift.git", exact: "1.0.0-alpha.1"),
        .package(url: "https://github.com/tadija/AEXML.git", from: "4.6.0")

    ],
    targets: [
        .target(
            name: "InjiVcRenderer",
            dependencies: [
                    .product(name: "pixelpass", package: "pixelpass-ios-swift"),
                    "AEXML"
                ]),
        .testTarget(
            name: "InjiVcRendererTests",
            dependencies: [
                "InjiVcRenderer",
                .product(name: "pixelpass", package: "pixelpass-ios-swift"),
                "AEXML"
            ])
    ]
)
