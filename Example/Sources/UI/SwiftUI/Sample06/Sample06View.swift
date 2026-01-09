//


import SwiftUI
import TinyRedux


extension SwiftUISample {
  
  struct Sample06View: View {
    let store = sample06Store
    
    var body: some View {
      _main_
        .onAppear { store.resume() }
        .onDisappear { store.suspend() }
    }
  }
}


#Preview {
  SwiftUISample.Sample06View()
}
