//

import TinyRedux


public let counterFeatureReducer: AnyReduxReducer<CounterFeatureState, CounterFeatureActions> = .init(id: "counterFeatureReducer")
{ context in
  let (state, action) = context.args

  switch action
  {
  case .increment:
    state.count += 1        // forwards through the binding → writes the app's value
    return .next
  case .decrement:
    state.count -= 1
    return .next
  }
}
