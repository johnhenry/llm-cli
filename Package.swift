// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "llm-cli",
    platforms: [
        .macOS("26.0")
    ],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.10.0")
    ],
    targets: [
        .executableTarget(
            name: "llm",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk")
            ],
            path: "Sources/llm"
        )
    ]
)
