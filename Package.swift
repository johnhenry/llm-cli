// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "llm-cli",
    platforms: [
        .macOS("26.0")
    ],
    dependencies: [
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui.git", from: "2.0.0")
    ],
    targets: [
        .executableTarget(
            name: "llm",
            dependencies: [],
            path: "Sources/llm"
        ),
        .executableTarget(
            name: "LLMApp",
            dependencies: [
                .product(name: "MarkdownUI", package: "swift-markdown-ui")
            ],
            path: "Sources/LLMApp"
        )
    ]
)
