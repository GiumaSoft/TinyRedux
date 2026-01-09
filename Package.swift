// swift-tools-version: 6.0

import CompilerPluginSupport
import PackageDescription

// Only the upcoming features NOT already implied by Swift 6 language mode are
// enabled here. The 14 flags Swift 6 implies were removed (each emitted a
// "feature '…' is already enabled as of Swift version 6" warning).
let upcomingFeatures: [SwiftSetting] = [
  .enableUpcomingFeature("InferIsolatedConformances"),
  .enableUpcomingFeature("NonisolatedNonsendingByDefault")
]

let package = Package(
  name: "TinyRedux",
  platforms: [
    .iOS(.v18),
    .macOS(.v15)
  ],
  products: [
    .library(
        name: "TinyRedux",
        type: .dynamic,
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
          .product(name: "SwiftDiagnostics", package: "swift-syntax"),
          .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
        ],
        path: "Sources/SwiftMacros"
    ),
    .target(
        name: "TinyRedux",
        dependencies: ["TinyReduxMacros"],
        path: "Sources",
        exclude: ["SwiftMacros"],
        swiftSettings: [
          .define("DEBUG", .when(configuration: .debug))
        ] + upcomingFeatures
    ),
    .testTarget(
        name: "TinyReduxTests",
        dependencies: ["TinyRedux"],
        path: "Tests",
        swiftSettings: upcomingFeatures
    )
  ],
  swiftLanguageModes: [.version("6")]
)
