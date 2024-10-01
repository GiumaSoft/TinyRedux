//


import SwiftUI
import TinyRedux


@main
struct ExampleApp: App {
  @StateObject private var store = Self.defaultStore
  @StateObject private var sample01Store = Self.sample01Store
  @StateObject private var sample02Store = Self.sample02Store
  @StateObject private var sample03Store = Self.sample03Store
  
  var body: some Scene {
    WindowGroup {
      ContentView()
        .environmentObject(store)
        .environmentObject(sample01Store)
        .environmentObject(sample02Store)
        .environmentObject(sample03Store)
    }
  }
}
