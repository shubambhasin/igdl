// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "IGDLMenuBar",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "IGDLMenuBar",
            path: "Sources/IGDLMenuBar"
        )
    ]
)
