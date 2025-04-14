//


import Foundation


typealias Sample02State = (
  timeCount: Int,
  timerIsRunning: Bool
)

extension AppState {
  var sample02: Sample02State {
    get {
      Sample02State(
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

