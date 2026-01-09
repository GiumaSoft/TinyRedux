//


import SwiftUI
import TinyRedux


extension SwiftUISample {
  
  struct Sample08View: View {
    let store = sample08Store
    
    var body: some View {
      _main_
        .onAppear { store.resume() }
        .onDisappear { store.suspend() }
    }
  }
}


#Preview {
  SwiftUISample.Sample08View()
}
