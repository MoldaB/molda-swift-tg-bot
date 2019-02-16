// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "MoldaTestBot",
    dependencies: [
        // 💧 A server-side Swift web framework.
        .package(url: "https://github.com/vapor/vapor.git", from: "3.0.0"),

        .package(url: "https://github.com/MoldaB/Telegrammer", from: "0.4.3"),
        
    ],
    targets: [
        .target(name: "App", dependencies: ["Telegrammer", "Vapor"]),
        .target(name: "Run", dependencies: ["App"]),
        .testTarget(name: "AppTests", dependencies: ["App"])
    ]
)

