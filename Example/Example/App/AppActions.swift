//


import Foundation


enum AppActions {
  case timer(TimerActions)
  case counter(CounterActions)
  case binding(BindingActions)
}

extension AppActions: Equatable {
  static func == (lhs: AppActions, rhs: AppActions) -> Bool {
    switch (lhs, rhs) {
    case (.timer(let left), .timer(let right)):
      left == right
    case (.counter(let left), .counter(let right)):
      left == right
    case (.binding(let left), .binding(let right)):
      left == right
    default:
      false
    }
  }
}
