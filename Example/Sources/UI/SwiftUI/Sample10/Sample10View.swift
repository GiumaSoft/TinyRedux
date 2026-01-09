//


import SwiftUI
import TinyRedux


extension SwiftUISample {
  
  struct Sample10View: View {
    let store = sample10Store
    
    var body: some View {
      _main_
        .onAppear { store.resume() }
        .onDisappear { store.suspend() }
    }
  }
}


#Preview {
  SwiftUISample.Sample10View()
}
