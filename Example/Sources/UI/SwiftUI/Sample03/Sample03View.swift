//


import Foundation
import SwiftUI
import TinyRedux

extension Sample.SwiftUI {
  struct Sample03View: View {
    @Global(\.mainStore) private var store
    
    let disclaimer = "This sample view demonstrate a how to integrate a Redux flow in a SwiftUI View that support unidirectional or bidirectional binding data flow."
  }
}

extension Sample.SwiftUI.Sample03View {
  
  var body: some View {
    VStack(spacing: 36) {
      Spacer()
      _unidirectionalBinding_
      Spacer()
      _disclaimer_
    }
  }

  @ViewBuilder private var _unidirectionalBinding_: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text("Unidirectional binding test")
        .font(.subheadline)
        .fontWeight(.bold)
      
      TextField("", text: headerBind)
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

extension Sample.SwiftUI.Sample03View {
  var headerBind: Binding<String> {
    store.bind(\.header) { .setHeader($0) }
  }
}


#Preview {
  Sample.SwiftUI.Sample03View()
    .padding()
}
