//


import SwiftUI
import TinyRedux


extension SwiftUISample {
  
  struct Sample02View: View {
    let store = sample02Store
    
    var body: some View {
      _main_
        .onAppear { store.resume() }
        .onDisappear { store.suspend() }
    }
  }
}


#Preview {
  SwiftUISample.Sample02View()
}
