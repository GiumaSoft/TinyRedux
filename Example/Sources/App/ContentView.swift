//


import Foundation
import SwiftUI


struct ContentView: View {
  var body: some View {
    NavigationStack {
      List {
        Section {
          NavigationLink("Sample01") {
            Sample.SwiftUI.Sample01View()
          }
          
          NavigationLink("Sample02") {
            Sample.SwiftUI.Sample02View()
          }
          
          NavigationLink("Sample03") {
            Sample.SwiftUI.Sample03View()
          }

          NavigationLink("Sample04") {
            Sample.SwiftUI.Sample04View()
          }
        } header: {
          Text("SwiftUI")
        }

        Section {
          NavigationLink("Sample04") {
            Sample.UIKit.Sample04View()
          }
        } header: {
          Text("UIKit")
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
}
