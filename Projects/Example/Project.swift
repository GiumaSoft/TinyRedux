// swift-tools-version:6.0
//
// Project.swift
@preconcurrency import ProjectDescription

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
    .package(product: "TinyRedux")
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


let project: Project = {
  let settings = Settings.settings(
    base: [
      "SWIFT_VERSION": "6"
    ],
    defaultSettings: .recommended
  )
  
  return Project(
    name: "Example",
    packages: [
      .package(path: "../../")
    ],
    settings: settings,
    targets: [
      exampleTarget,
      exampleTestsTarget
    ]
  )
}()
