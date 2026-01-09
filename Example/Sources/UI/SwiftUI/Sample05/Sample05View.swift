//


import SwiftUI
import TinyRedux


extension Sample.SwiftUI {
  
  struct Sample05View: View {
    @Global(\.sample05Store) var store
    @State var activeAxis: Sample05Action?
    
    var body: some View {
      _main_
        .onAppear { store.resume() }
        .onDisappear { store.suspend() }
        .task(id: activeAxis) {
          guard let action = activeAxis else { return }
          while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            store.dispatch(action)
          }
        }
    }
  }
}


#Preview {
  Sample.SwiftUI.Sample05View()
}
