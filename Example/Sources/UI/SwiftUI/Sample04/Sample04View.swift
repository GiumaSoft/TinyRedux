//

import SwiftUI
import TinyRedux

extension Sample.SwiftUI {
  struct Sample04View: View {
    @Global(\.sample04Store) var store
    
    
    let disclaimer = "This sample view demonstrates runTask by triggering an async task in middleware and updating state when it completes."
    
    var body: some View {
      _main_
        .onAppear { store.resume() }
        .onDisappear { store.suspend() }
    }
  }
}


#Preview {
  Sample.SwiftUI.Sample04View()
    .padding()
}
