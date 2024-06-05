//


import Foundation
import SwiftUI


struct ContentView: View {
  var body: some View {
    NavigationStack {
      List {
        NavigationLink("AsyncCounter") {
          AsyncCounter()
        }
        NavigationLink("DigitalTimer") {
          DigitalTimerView()
        }
        NavigationLink("UnidirectionalBinding") {
          UnidirectionalBindingView()
        }
      }
      .listStyle(.plain)
    }
  }
}



#Preview {
  ContentView()
    .padding()
    .environmentObject(
      ExampleApp.timerStore
    )
    .environmentObject(
      ExampleApp.counterStore
    )
    .environmentObject(
      ExampleApp.bindingStore
    )
}
