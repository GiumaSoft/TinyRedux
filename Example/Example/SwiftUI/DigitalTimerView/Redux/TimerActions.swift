//


import Foundation


enum TimerActions {
  case startTimer
  case stopTimer
  case updateTimer
}

extension TimerActions: Equatable {
  static func == (lhs: TimerActions, rhs: TimerActions) -> Bool {
    switch (lhs, rhs) {
    case (.startTimer, .startTimer),
         (.stopTimer, .stopTimer),
         (.updateTimer, .updateTimer):
          true
    default:
          false
    }
  }
}

extension AppActions {
  var timer: TimerActions? {
    get { if case .timer(let value) = self { value } else { nil } }
    set { if case .timer = self, let newValue { self = .timer(newValue) } else { return } }
  }
}
