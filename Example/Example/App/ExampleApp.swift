//


import SwiftUI
import TinyRedux


@main
struct ExampleApp: App {
  @StateObject private var store = Self.defaultStore
  @StateObject private var bindingStore = Self.bindingStore
  @StateObject private var counterStore = Self.counterStore
  @StateObject private var timerStore = Self.timerStore
  
  var body: some Scene {
    WindowGroup {
      ContentView()
        .environmentObject(store)
        .environmentObject(bindingStore)
        .environmentObject(counterStore)
        .environmentObject(timerStore)
    }
  }
}
