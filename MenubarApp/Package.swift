// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "IGDLMenuBar",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "IGDLMenuBar",
            path: "Sources/IGDLMenuBar"
        )
    ]
)
