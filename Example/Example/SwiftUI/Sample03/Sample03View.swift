//


import Foundation
import SwiftUI
import TinyRedux

extension Sample.SwiftUI {
  struct Sample03View {
    @EnvironmentObject private var store: SubStore<AppState, AppActions, Sample03State, Sample03Actions>
    
    let disclaimer = "This sample view demonstrate a how to integrate a Redux flow in a SwiftUI View that support unidirectional or bidirectional binding data flow."
  }
}

extension Sample.SwiftUI.Sample03View: View {
  
  var body: some View {
    VStack(spacing: 36) {
      Spacer()
      _bidirectionalBinding_
      _unidirectionalBinding_
      Spacer()
      _disclaimer_
    }
  }
  
  @ViewBuilder private var _bidirectionalBinding_: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text("Bidirectional binding test")
        .font(.subheadline)
        .fontWeight(.bold)

      TextField("", text: store.bind(\.header))
        .font(.title)
        .padding()
        .background(
          RoundedRectangle(cornerRadius: 16)
            .fill(Material.regular)
        )
    }
  }

  @ViewBuilder private var _unidirectionalBinding_: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text("Unidirectional binding test")
        .font(.subheadline)
        .fontWeight(.bold)
      
      TextField("", text: store.reducedBind(\.header, { .setHeader($0) }))
        .font(.title)
        .padding()
        .background(
          RoundedRectangle(cornerRadius: 16)
            .fill(Material.regular)
        )
    }
  }
  
  @ViewBuilder private var _disclaimer_: some View {
    Text(disclaimer)
      .multilineTextAlignment(.center)
      .font(.subheadline)
      .fontWeight(.bold)
      .padding()
  }
}


#Preview {
  Sample.SwiftUI.Sample03View()
    .padding()
    .environmentObject(
      ExampleApp.sample03Store
    )
}
