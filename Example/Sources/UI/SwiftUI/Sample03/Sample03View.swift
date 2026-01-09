//


import SwiftUI
import TinyRedux

extension Sample.SwiftUI {
  struct Sample03View: View {
    @Global(\.sample03Store) var store
    
    let disclaimer = "This sample view demonstrate a how to integrate a Redux flow in a SwiftUI View that support unidirectional or bidirectional binding data flow."
    
    var body: some View {
      _main_
        .onAppear { store.resume() }
        .onDisappear { store.suspend() }
    }
  }
}


#Preview {
  Sample.SwiftUI.Sample03View()
    .padding()
}
