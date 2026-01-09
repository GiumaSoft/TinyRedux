//


import SwiftUI
import TinyRedux


extension SwiftUISample {
  
  struct Sample17View: View {
    let store = sample17Store
    
    var body: some View {
      _main_
        .onAppear { store.resume() }
        .onDisappear { store.suspend() }
    }
  }
}


#Preview {
  SwiftUISample.Sample17View()
}
