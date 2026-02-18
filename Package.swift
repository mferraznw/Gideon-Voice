// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GideonTalk",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "GideonTalk", targets: ["GideonTalk"])
    ],
    targets: [
        .executableTarget(
            name: "GideonTalk",
            path: "Sources/GideonTalk",
            exclude: ["Info.plist"]
        )
    ]
)
