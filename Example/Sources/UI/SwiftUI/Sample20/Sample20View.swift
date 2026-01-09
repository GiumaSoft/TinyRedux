//


import SwiftUI
import TinyRedux


extension SwiftUISample {
  
  struct Sample20View: View {
    let store = sample20Store
    
    var body: some View {
      _main_
        .onAppear { store.resume() }
        .onDisappear { store.suspend() }
    }
  }
}


#Preview {
  SwiftUISample.Sample20View()
}
