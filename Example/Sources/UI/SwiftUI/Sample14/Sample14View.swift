//


import SwiftUI
import TinyRedux


extension SwiftUISample {
  
  struct Sample14View: View {
    let store = sample14Store
    
    var body: some View {
      _main_
        .onAppear { store.resume() }
        .onDisappear { store.suspend() }
    }
  }
}


#Preview {
  SwiftUISample.Sample14View()
}
