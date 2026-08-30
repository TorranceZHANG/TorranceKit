// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "TorranceKit",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "TorranceKit", targets: ["TorranceKit"])
    ],
    targets: [
        .executableTarget(
            name: "TorranceKit",
            path: "Sources/TorranceKit"
        ),
        .testTarget(
            name: "TorranceKitTests",
            dependencies: ["TorranceKit"],
            path: "Tests/TorranceKitTests"
        )
    ]
)
