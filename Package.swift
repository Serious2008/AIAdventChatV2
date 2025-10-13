// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AIAdventChatV2",
    platforms: [
        .macOS(.v15)
    ],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.10.0")
    ],
    targets: [
        .target(
            name: "AIAdventChatV2",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk")
            ]
        )
    ]
)
