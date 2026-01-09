//


import SwiftUI
import TinyRedux


extension SwiftUISample {
  
  struct Sample16View: View {
    let store = sample16Store
    
    var body: some View {
      _main_
        .onAppear { store.resume() }
        .onDisappear { store.suspend() }
    }
  }
}


#Preview {
  SwiftUISample.Sample16View()
}
