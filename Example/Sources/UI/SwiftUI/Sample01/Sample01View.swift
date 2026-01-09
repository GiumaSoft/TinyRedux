//


import SwiftUI
import TinyRedux


extension Sample.SwiftUI {
  
  struct Sample01View: View {
    @Global(\.sample01Store) var store
    
    let disclaimer = """
                     This sample view demonstrate a how to integrate a Redux
                     flow in a SwiftUI View dispatching actions that add or 
                     remove items from the List view in a synchronous way.
                     """
    var body: some View {
      _main_
        .onAppear { store.resume() }
        .onDisappear { store.suspend() }
    }
  }
}


#Preview {
  Sample.SwiftUI.Sample01View()
}
