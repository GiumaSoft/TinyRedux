import ProjectDescription

let tuist = Tuist(
  project: .tuist(
    compatibleXcodeVersions: .upToNextMajor(.init(26, 2, 0)),
    swiftVersion: .init(6, 0, 0),
    //plugins: [],
    generationOptions: .options(
      //disablePackageVersionLocking: <#T##Bool#>,
      //staticSideEffectsWarningTargets: <#T##Tuist.GenerationOptions.StaticSideEffectsWarningTargets#>,
      //defaultConfiguration: <#T##String?#>,
      //optionalAuthentication: <#T##Bool#>,
      //buildInsightsDisabled: <#T##Bool#>,
      //testInsightsDisabled: <#T##Bool#>,
      //disableSandbox: <#T##Bool#>,
      includeGenerateScheme: true,
      //enableCaching: <#T##Bool#>,
      //additionalPackageResolutionArguments: <#T##[String]#>
    ),
    //installOptions: <#T##Tuist.InstallOptions#>,
    //cacheOptions: <#T##Tuist.CacheOptions#>
  )
)
