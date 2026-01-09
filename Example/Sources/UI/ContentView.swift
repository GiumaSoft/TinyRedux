//

import CounterFeature
import SwiftUI
import TinyRedux


struct ContentView: View
{
  @State private var store = AppModules.makeStore()

  var body: some View {
    VStack(spacing: 24) {
      // The app's own view of the counter (its `Int`).
      Text("App counter: \(store.state.counter)")
        .font(.largeTitle)

      // Top-level AppActions, routed to the module via the scattered action mapping.
      HStack(spacing: 24) {
        Button("App −") { store.dispatch(.decrement) }
        Button("App +") { store.dispatch(.increment) }
      }

      Divider()

      // The EXTERNAL module: sees and mutates the SAME counter via its ReduxMappedState,
      // wired through the `.counter` mapping/slice — without knowing AppState.
      CounterFeatureView(module: store.slice(AppModules.counterMap))
    }
    .padding()
  }
}


#Preview {
  ContentView()
}
