//


import SwiftUI
import TinyRedux


extension SwiftUISample {
  
  struct Sample04View: View {
    let store = sample04Store
    
    var body: some View {
      _main_
        .onAppear { store.resume() }
        .onDisappear { store.suspend() }
    }
  }
}


#Preview {
  SwiftUISample.Sample04View()
}
