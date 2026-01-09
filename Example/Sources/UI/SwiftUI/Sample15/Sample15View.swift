//


import SwiftUI
import TinyRedux


extension SwiftUISample {
  
  struct Sample15View: View {
    let store = sample15Store
    
    var body: some View {
      _main_
        .onAppear { store.resume() }
        .onDisappear { store.suspend() }
    }
  }
}


#Preview {
  SwiftUISample.Sample15View()
}
