//


import Foundation
import TinyRedux


let sample02Reducer = Reducer<AppState, Sample02Actions> { state, action in
  
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
  }
}
