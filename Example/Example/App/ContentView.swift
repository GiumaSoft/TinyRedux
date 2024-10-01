//


import Foundation
import SwiftUI


struct ContentView: View {
  var body: some View {
    NavigationStack {
      List {
        NavigationLink("Sample01") {
          Sample.SwiftUI.Sample01View()
        }
        
        NavigationLink("Sample02") {
          Sample.SwiftUI.Sample02View()
        }
        
        NavigationLink("Sample03") {
          Sample.SwiftUI.Sample03View()
        }
      }
      .listStyle(.plain)
      .safeAreaPadding(.top)
    }
  }
}



#Preview {
  ContentView()
    .padding()
    .environmentObject(
      ExampleApp.sample01Store
    )
    .environmentObject(
      ExampleApp.sample02Store
    )
    .environmentObject(
      ExampleApp.sample03Store
    )
}
