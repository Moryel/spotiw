// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "spotiw",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .library(
            name: "SpotifPockWidget",
            type: .dynamic,
            targets: ["SpotifPockWidget"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/pock/pockkit.git", branch: "master")
    ],
    targets: [
        .target(
            name: "SpotifPockWidget",
            dependencies: [
                .product(name: "PockKit", package: "pockkit")
            ],
            exclude: [
                "Info.plist",
                "PockKit.framework"
            ],
            linkerSettings: [
                .linkedFramework("AppKit")
            ]
        )
    ]
)
