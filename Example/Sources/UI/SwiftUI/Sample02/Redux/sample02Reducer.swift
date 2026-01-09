//


import Foundation
import TinyRedux


@MainActor
let sample02Reducer = Reducer<AppState, AppActions>(id: "sample02Reducer") { context in
  
  let (state, action) = context.args
  
  switch action {
  case .decrease:
    if state.timeCount > 0 {
      state.timeCount -= 1
    }
  case .increase:
    state.timeCount += 1
  case .startAutoCounter:
    state.timerIsRunning = true
  case .stopAutoCounter:
    state.timerIsRunning = false
  default:
    break
  }
}
