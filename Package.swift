// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "TabletDriver",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .target(
            name: "TabletDriverKit"
        ),
        .executableTarget(
            name: "TabletDriverApp",
            dependencies: ["TabletDriverKit"]
        ),
        .testTarget(
            name: "TabletDriverKitTests",
            dependencies: ["TabletDriverKit"]
        )
    ]
)
