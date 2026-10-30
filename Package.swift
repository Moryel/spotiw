// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "spotiw",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "Spotiw", targets: ["Spotiw"])
    ],
    targets: [
        .executableTarget(
            name: "Spotiw",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ServiceManagement")
            ]
        )
    ]
)
