// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TinyRedux",
    platforms: [
      .iOS(.v14), .macOS(.v13)
    ],
    products: [
        .library(
            name: "TinyRedux",
            type: .dynamic,
            targets: ["TinyRedux"]
        )
    ],
    targets: [
        .target(
            name: "TinyRedux"
        ),
        .testTarget(
            name: "TinyReduxTests",
            dependencies: ["TinyRedux"]
        )
    ]
)
