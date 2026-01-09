// swift-tools-version: 6.0

import CompilerPluginSupport
import PackageDescription

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
    .package(url: "https://github.com/swiftlang/swift-syntax", from: "602.0.0")
  ],
  targets: [
    .macro(
        name: "TinyReduxMacros",
        dependencies: [
          .product(name: "SwiftSyntax", package: "swift-syntax"),
          .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
          .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
        ],
        path: "Sources/Types/SwiftMacros",
        swiftSettings: [
          .enableUpcomingFeature("Swift6"),
          .enableUpcomingFeature("StrictConcurrency")
        ]
    ),
    .target(
        name: "TinyRedux",
        dependencies: ["TinyReduxMacros"],
        path: "Sources",
        exclude: ["Types/SwiftMacros"],
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
