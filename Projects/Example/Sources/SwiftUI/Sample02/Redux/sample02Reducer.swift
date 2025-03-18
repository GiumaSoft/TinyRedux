//


import Foundation
import TinyRedux


@MainActor
let sample02Reducer = Reducer<Sample02State, Sample02Actions> { state, action in
  print("Entering Sample02 Reducer...")
  switch action {
  case .decrease:
    if state.timeCount > 0 {
      state.timeCount -= 1
    }
  case .increase:
    state.timeCount += 1
  case .startTimer:
    state.timerIsRunning = true
  case .stopTimer:
    state.timerIsRunning = false
  default:
    break
  }
}
