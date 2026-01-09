//


import SwiftUI
import TinyRedux


extension SwiftUISample {
  
  struct Sample05View: View {
    let store = sample05Store
    
    var body: some View {
      _main_
        .onAppear { store.resume() }
        .onDisappear { store.suspend() }
    }
  }
}


#Preview {
  SwiftUISample.Sample05View()
}
