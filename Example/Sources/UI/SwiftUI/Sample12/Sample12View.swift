//


import SwiftUI
import TinyRedux


extension SwiftUISample {
  
  struct Sample12View: View {
    let store = sample12Store
    
    var body: some View {
      _main_
        .onAppear { store.resume() }
        .onDisappear { store.suspend() }
    }
  }
}


#Preview {
  SwiftUISample.Sample12View()
}
