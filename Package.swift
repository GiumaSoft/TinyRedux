// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

@preconcurrency import PackageDescription

let package = Package(
  name: "TinyRedux",
  platforms: [
    .iOS(.v18),
    .macOS(.v15)
  ],
  products: [
    .library(
        name: "TinyRedux",
        targets: ["TinyRedux"]
    )
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-collections.git", from: "1.3.0")
  ],
  targets: [
    .target(
        name: "TinyRedux",
        dependencies: [
            .product(name: "Collections", package: "swift-collections")
        ],
        path: "Sources",
        swiftSettings: [
          .define("DEBUG", .when(configuration: .debug)),
          .enableUpcomingFeature("Swift6"),
          .enableUpcomingFeature("StrictConcurrency")
        ]
    ),
    .testTarget(
        name: "TinyReduxTests",
        dependencies: ["TinyRedux"],
        path: "Tests",
        swiftSettings: [
          .enableUpcomingFeature("Swift6"),
          .enableUpcomingFeature("StrictConcurrency")
        ]
    )
  ],
  swiftLanguageModes: [.version("6")]
)
