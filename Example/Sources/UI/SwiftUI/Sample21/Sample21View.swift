//


import SwiftUI
import TinyRedux


extension SwiftUISample {
  
  struct Sample21View: View {
    let store = sample21Store
    
    var body: some View {
      _main_
        .onAppear { store.resume() }
        .onDisappear { store.suspend() }
    }
  }
}


#Preview {
  SwiftUISample.Sample21View()
}
