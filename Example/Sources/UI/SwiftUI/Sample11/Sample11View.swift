//


import SwiftUI
import TinyRedux


extension SwiftUISample {
  
  struct Sample11View: View {
    let store = sample11Store
    
    var body: some View {
      _main_
        .onAppear { store.resume() }
        .onDisappear { store.suspend() }
    }
  }
}


#Preview {
  SwiftUISample.Sample11View()
}
