//


import Foundation
import TinyRedux


@MainActor
let timerReducer = Reducer<TimerState, TimerActions> { state, action in
  switch action {
  case .startTimer:
    state.timerIsRunning = true
  case .stopTimer:
    state.timerIsRunning = false
  case .updateTimer:
    state.timeCount += 1
  }
}
