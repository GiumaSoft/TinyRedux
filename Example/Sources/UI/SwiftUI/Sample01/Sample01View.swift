//


import SwiftUI
import TinyRedux


extension SwiftUISample {
  
  struct Sample01View: View {
    let store = sample01Store
    
    var body: some View {
      _main_
        .onAppear { store.resume() }
        .onDisappear { store.suspend() }
    }
  }
}


#Preview {
  SwiftUISample.Sample01View()
}
