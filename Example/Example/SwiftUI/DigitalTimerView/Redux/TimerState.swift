//


import Foundation


typealias TimerState = (
  timeCount: Int,
  timerIsRunning: Bool
)

extension AppState {
  var timerState: TimerState {
    get {
      TimerState(
        self.timeCount,
        self.timerIsRunning
      )
    }
    set {
      (
        self.timeCount,
        self.timerIsRunning
      ) = newValue
    }
  }
}

