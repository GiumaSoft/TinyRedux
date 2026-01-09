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
    .package(product: "TinyRedux")
  ]
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


let project: Project = {
  let settings = Settings.settings(
    base: [
      "SWIFT_VERSION": "6",
      "SWIFT_STRICT_CONCURRENCY": "complete"
    ],
    defaultSettings: .recommended
  )
  
  return Project(
    name: "Example",
    packages: [
      .package(path: "../")
    ],
    settings: settings,
    targets: [
      exampleTarget,
      exampleTestsTarget
    ]
  )
}()
