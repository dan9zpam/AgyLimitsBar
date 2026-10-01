// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AgyLimitsBar",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "AgyLimitsBar",
            path: "AgyLimitsBar"
        )
    ]
)
