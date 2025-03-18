import ProjectDescription

let exampleTarget = Target.target(
  name: "Example",
  destinations: .iOS,
  product: .app,
  bundleId: "com.GiumaSoft.TinyRedux.Example",
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
    .package(product: "TinyRedux", type: .runtimeEmbedded)
  ]
)

let exampleTestsTarget = Target.target(
  name: "ExampleTests",
  destinations: .iOS,
  product: .unitTests,
  bundleId: "com.GiumaSoft.TinyRedux.ExampleTests",
  infoPlist: .default,
  sources: [
    "Tests/**"
  ],
  dependencies: [
    .target(name: "Example")
  ]
)

let project = Project(
  name: "Example",
  packages: [
    .package(path: "../../")
  ],
  targets: [
    exampleTarget,
    exampleTestsTarget
  ]
)
