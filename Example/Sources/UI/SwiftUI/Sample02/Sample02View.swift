//


import SwiftUI
import TinyRedux


extension Sample.SwiftUI {
  struct Sample02View: View {
    @Global(\.sample02Store) var store
    
    let disclaimer = "This sample view demonstrate a how to integrate a Redux flow in a SwiftUI View dispatching actions that increase or decrease counter in a synchronous way. Additionally tapping on Timer start or stop an asynchronous automatic counter increment."
    
    var body: some View {
      _main_
        .onAppear { store.resume() }
        .onDisappear { store.suspend() }
    }
  }
}


#Preview {
  Sample.SwiftUI.Sample02View()
    .padding()
}
