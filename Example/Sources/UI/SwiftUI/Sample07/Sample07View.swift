//


import SwiftUI
import TinyRedux


extension SwiftUISample {
  
  struct Sample07View: View {
    let store = sample07Store
    
    var body: some View {
      _main_
        .onAppear { store.resume() }
        .onDisappear { store.suspend() }
    }
  }
}


#Preview {
  SwiftUISample.Sample07View()
}
