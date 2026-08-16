// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ZipMip",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "ZipMipCore", targets: ["ZipMipCore"]),
        .executable(name: "ZipMip", targets: ["ZipMip"])
    ],
    targets: [
        .target(
            name: "ZipMipCore",
            dependencies: [],
            path: "Sources/ZipMipCore"
        ),
        .executableTarget(
            name: "ZipMip",
            dependencies: ["ZipMipCore"],
            path: "Sources/ZipMip",
            exclude: ["Info.plist"],
            resources: [
                .copy("Resources")
            ]
        ),
        .testTarget(
            name: "ZipMipTests",
            dependencies: ["ZipMipCore"],
            path: "Tests/ZipMipTests"
        )
    ]
)
