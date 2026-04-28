// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "HiveCompose",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "HiveCompose",
            targets: ["HiveCompose"]
        )
    ],
    targets: [
        .target(
            name: "HiveCompose"
        )
    ]
)
