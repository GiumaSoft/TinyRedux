//


import SwiftUI
import TinyRedux


extension SwiftUISample {
  
  struct Sample03View: View {
    let store = sample03Store
    
    var body: some View {
      _main_
        .onAppear { store.resume() }
        .onDisappear { store.suspend() }
    }
  }
}


#Preview {
  SwiftUISample.Sample03View()
}
