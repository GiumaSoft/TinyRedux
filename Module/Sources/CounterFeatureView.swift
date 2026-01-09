//

import SwiftUI
import TinyRedux


public struct CounterFeatureView: View
{
  let module: any ReduxModule<CounterFeatureState, CounterFeatureActions>

  public init(module: any ReduxModule<CounterFeatureState, CounterFeatureActions>)
  {
    self.module = module
  }

  public var body: some View {
    VStack(spacing: 12) {
      Text("Module sees count: \(module.state.count)")
        .font(.headline)

      HStack(spacing: 24) {
        Button("−") { module.dispatch(.decrement) }
        Button("+") { module.dispatch(.increment) }
      }
    }
  }
}
