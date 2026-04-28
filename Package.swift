// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ReframePhoto",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ReframePhoto",
            targets: ["ReframePhoto"]
        )
    ],
    targets: [
        .target(
            name: "ReframePhoto"
        )
    ]
)
