//


import SwiftUI
import TinyRedux


extension SwiftUISample {
  
  struct Sample09View: View {
    let store = sample09Store
    
    var body: some View {
      _main_
        .onAppear { store.resume() }
        .onDisappear { store.suspend() }
    }
  }
}


#Preview {
  SwiftUISample.Sample09View()
}
