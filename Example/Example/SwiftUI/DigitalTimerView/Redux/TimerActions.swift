//


import Foundation


enum TimerActions {
  case startTimer
  case stopTimer
  case updateTimer
}

extension AppActions {
  var timer: TimerActions? {
    get { if case .timer(let value) = self { value } else { nil } }
    set { if case .timer = self, let newValue { self = .timer(newValue) } else { return } }
  }
}
