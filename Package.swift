// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NotificationBar",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "NotificationBar", path: "Sources/NotificationBar")
    ]
)
