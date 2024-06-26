//


import Foundation
import TinyRedux


@MainActor
let counterReducer = Reducer<CounterState, CounterActions> { state, action in
  print("Entering counterReducer")
  switch action {
  case .decreaseCounter:
    state.counter -= 1
    return
  case .increaseCounter:
    state.counter += 1
    return
  default:
    break
  }
}
