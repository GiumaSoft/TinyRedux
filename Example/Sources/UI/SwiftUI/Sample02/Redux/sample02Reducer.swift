//


import Foundation
import TinyRedux


let sample02Reducer = AnyReducer<Sample02State, Sample02Action>(id: "sample02Reducer") { context in

  let (state, action) = context.args

  switch action {
  case .decrease:
    if state.timeCount > 0 {
      state.timeCount -= 1
    }
    return .next
  case .increase:
    state.timeCount += 1
    return .next
  case .startAutoCounter:
    state.timerIsRunning = true
    return .next
  case .stopAutoCounter:
    state.timerIsRunning = false
    return .next
  }
}
