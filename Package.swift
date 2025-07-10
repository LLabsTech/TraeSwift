// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TraeSwift",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.6.1"),
        .package(url: "https://github.com/Maxim-Lanskoy/ShellOut.git", from: "2.4.0"),
        .package(url: "https://github.com/MacPaw/OpenAI", from: "0.4.4"),
        .package(url: "https://github.com/KittyMac/Sextant.git", from: "0.4.35")
    ],
    targets: [
        .executableTarget(
            name: "TraeSwift",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "ShellOut", package: "ShellOut"),
                .product(name: "OpenAI", package: "OpenAI"),
                .product(name: "Sextant", package: "Sextant")
            ],
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]),
        .testTarget(
            name: "TraeSwiftTests",
            dependencies: ["TraeSwift"],
            path: "TraeTests"
        ),
    ]
)
