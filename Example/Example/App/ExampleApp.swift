//


import SwiftUI
import TinyRedux


@main
struct ExampleApp: App {
  @StateObject private var store = Self.defaultStore
  @StateObject private var timerStore = Self.timerStore
  
  var body: some Scene {
    WindowGroup {
      ContentView()
        .environmentObject(store)
        .environmentObject(timerStore)
    }
  }
}
