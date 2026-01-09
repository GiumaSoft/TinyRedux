//


import Foundation
import TinyRedux


@MainActor
let sample02Reducer = AnyReducer<AppState, AppActions>(id: "sample02Reducer") { context in
  
  let (state, action) = context.args
  
  switch action {
  case .decrease:
    if state.timeCount > 0 {
      state.timeCount -= 1
    }
    context.complete()
  case .increase:
    state.timeCount += 1
    context.complete()
  case .startAutoCounter:
    state.timerIsRunning = true
    context.complete()
  case .stopAutoCounter:
    state.timerIsRunning = false
    context.complete()
  default:
    break
  }
}
