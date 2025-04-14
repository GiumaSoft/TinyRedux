//


import Foundation
import TinyRedux


@MainActor
let sample02Reducer = Reducer<AppState, AppActions>(id: "sample02Reducer") { state, context in
  let action = context.action
  
  switch action {
  case .decrease:
    context.handled()
    if state.timeCount > 0 {
      state.timeCount -= 1
    }
  case .increase:
    context.handled()
    state.timeCount += 1
  case .startAutoCounter:
    context.handled()
    state.timerIsRunning = true
  case .stopAutoCounter:
    context.handled()
    state.timerIsRunning = false
  default:
    break
  }
}
