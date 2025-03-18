//


import SwiftUI
import TinyRedux


@main
struct ExampleApp: App {
  @State private var defaultStore = Self.defaultStore
  @State private var sample01Store = Self.sample01Store
  @State private var sample02Store = Self.sample02Store
  @State private var sample03Store = Self.sample03Store
  
  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(defaultStore)
        .environment(sample01Store)
        .environment(sample02Store)
        .environment(sample03Store)
    }
  }
}
