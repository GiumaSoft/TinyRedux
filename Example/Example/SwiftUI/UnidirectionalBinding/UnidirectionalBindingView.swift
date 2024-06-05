//


import Foundation
import SwiftUI
import TinyRedux


struct UnidirectionalBindingView: View {
  @EnvironmentObject private var store: SubStore<AppState, AppActions, BindingState, BindingActions>
  
  var body: some View {
    VStack {
      _bidirectionalBinding_
      _unidirectionalBinding_
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
    }
  }
}


#Preview {
  UnidirectionalBindingView()
    .padding()
    .environmentObject(
      ExampleApp.bindingStore
    )
}
