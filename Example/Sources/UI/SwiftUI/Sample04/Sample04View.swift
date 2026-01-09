//

import SwiftUI
import TinyRedux

extension Sample.SwiftUI {
  struct Sample04View: View {
    @Global(\.mainStore) var store
    
    
    let disclaimer = "This sample view demonstrates runTask by triggering an async task in middleware and updating state when it completes."
    
    var body: some View {
      _main_
    }
  }
}


#Preview {
  Sample.SwiftUI.Sample04View()
    .padding()
}
