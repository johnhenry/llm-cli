// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "llm-cli",
    platforms: [
        .macOS("26.0")
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "llm",
            dependencies: [],
            path: "Sources/llm",
            linkerSettings: [
                .linkedFramework("Network")
            ]
        )
    ]
)
