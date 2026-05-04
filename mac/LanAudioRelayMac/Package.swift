// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "LanAudioRelayMac",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "LanAudioRelayMac", targets: ["LanAudioRelayMac"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/alta/swift-opus.git",
            revision: "6f3cb6bd3ffed1fe5f06d00a962d5c191a50daf8"
        )
    ],
    targets: [
        .target(
            name: "LanAudioRelayMacCore",
            dependencies: [
                .product(name: "Copus", package: "swift-opus")
            ]
        ),
        .executableTarget(
            name: "LanAudioRelayMac",
            dependencies: ["LanAudioRelayMacCore"]
        ),
        .testTarget(
            name: "LanAudioRelayMacCoreTests",
            dependencies: ["LanAudioRelayMacCore"]
        )
    ]
)
