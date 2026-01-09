// swift-tools-version:6.0


@preconcurrency
import ProjectDescription


let exampleTarget = Target.target(
  name: "Example",
  destinations: .iOS,
  product: .app,
  bundleId: "com.gmsoft.TinyRedux.Example",
  infoPlist: .extendingDefault(
    with: [
      "UILaunchStoryboardName": "LaunchScreen.storyboard"
    ]
  ),
  sources: ["Sources/**"],
  resources: [
  "Resources/**",
  "Sources/**/*.xib"
  ],
  dependencies: [
    .package(product: "TinyRedux", type: .runtimeEmbedded),
    .package(product: "OrderedCollections"),
    .package(product: "DequeModule"),
    .package(product: "Logging"),
    .target(name: "CounterFeature")            // the external module
  ]
)

// External module imported by the app: lives in ../Module, depends only on TinyRedux.
// Links TinyRedux (the app embeds it, so no double-embed here).
let counterFeatureTarget = Target.target(
  name: "CounterFeature",
  destinations: .iOS,
  product: .framework,
  bundleId: "com.gmsoft.TinyRedux.CounterFeature",
  infoPlist: .default,
  sources: [
    "../Module/Sources/**"
  ],
  dependencies: [
    .package(product: "TinyRedux")
  ],
  settings: .settings(
    base: [
      // Recommended for framework targets that define a clang module.
      "ENABLE_MODULE_VERIFIER": "YES",
      "MODULE_VERIFIER_SUPPORTED_LANGUAGES": "objective-c objective-c++",
      "MODULE_VERIFIER_SUPPORTED_LANGUAGE_STANDARDS": "gnu17 gnu++20"
    ]
  )
)

let exampleTestsTarget = Target.target(
  name: "ExampleTests",
  destinations: .iOS,
  product: .unitTests,
  bundleId: "com.gmsoft.TinyRedux.ExampleTests",
  infoPlist: .default,
  sources: [
    "Tests/**"
  ],
  dependencies: [
    .target(name: "Example")
  ]
)


// Runs the TinyRedux SPM package's tests (root `Tests/**`, Swift Testing) from
// the Example workspace. Defined as a Tuist target so it survives `tuist generate`
// (a hand-written .xcscheme would be overwritten). Host-less logic-test bundle,
// matching `swift test` semantics; links the package product for `@testable import`.
let tinyReduxTestsTarget = Target.target(
  name: "TinyReduxTests",
  destinations: .iOS,
  product: .unitTests,
  bundleId: "com.gmsoft.TinyRedux.TinyReduxTests",
  infoPlist: .default,
  sources: [
    "../Tests/**"
  ],
  dependencies: [
    .package(product: "TinyRedux", type: .runtimeEmbedded)
  ]
)

let tinyReduxTestsScheme = Scheme.scheme(
  name: "TinyReduxTests",
  shared: true,
  buildAction: .buildAction(targets: [.target("TinyReduxTests")]),
  testAction: .targets(
    [.testableTarget(target: .target("TinyReduxTests"))],
    configuration: .debug
  )
)

let project: Project = {
  let settings = Settings.settings(
    base: [
      "SWIFT_VERSION": "6",
      "SWIFT_STRICT_CONCURRENCY": "complete",
      // Xcode "recommended settings" deltas not covered by Tuist's `.recommended`
      // (captured from Xcode's "Update to recommended settings" dialog).
      "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
      "ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS": "YES",
      "STRING_CATALOG_GENERATE_SYMBOLS": "YES"
    ],
    defaultSettings: .recommended
  )
  
  return Project(
    name: "Example",
    packages: [
      .package(url: "https://github.com/apple/swift-collections", .exact("1.4.1")),
      .package(url: "https://github.com/apple/swift-log", .exact("1.11.0")),
      .package(path: "../")
    ],
    settings: settings,
    targets: [
      exampleTarget,
      counterFeatureTarget,
      exampleTestsTarget,
      tinyReduxTestsTarget
    ],
    schemes: [
      tinyReduxTestsScheme
    ]
  )
}()
