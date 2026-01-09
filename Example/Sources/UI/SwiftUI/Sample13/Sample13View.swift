//


import SwiftUI
import TinyRedux


extension SwiftUISample {
  
  struct Sample13View: View {
    let store = sample13Store
    
    var body: some View {
      _main_
        .onAppear { store.resume() }
        .onDisappear { store.suspend() }
    }
  }
}


#Preview {
  SwiftUISample.Sample13View()
}
