//


import SwiftUI
import TinyRedux


extension SwiftUISample {
  
  struct Sample18View: View {
    let store = sample18Store
    
    var body: some View {
      _main_
        .onAppear { store.resume() }
        .onDisappear { store.suspend() }
    }
  }
}


#Preview {
  SwiftUISample.Sample18View()
}
