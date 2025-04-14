// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

@preconcurrency import PackageDescription

let package = Package(
    name: "TinyRedux",
    platforms: [
      .iOS(.v17), .macOS(.v14), .macCatalyst(.v14)
    ],
    products: [
        .library(
            name: "TinyRedux",
            targets: ["TinyRedux"]
        )
    ],
    targets: [
        .target(
            name: "TinyRedux",
            path: "Sources"
        ),
        .testTarget(
            name: "TinyReduxTests",
            dependencies: ["TinyRedux"]
        )
    ]
)
