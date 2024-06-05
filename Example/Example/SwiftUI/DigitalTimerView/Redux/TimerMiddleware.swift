//


import Foundation
import TinyRedux


final class TimerMiddleware: Middleware {
  private var timer: Timer?
  
  func run(_ args: RunArguments<TimerState, TimerActions>) {
    print("Entering TimerMiddleware...")
    
    let (_, dispatch, next, action) = args
    
    switch action {
    case .startTimer:
      if timer == nil {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
          dispatch(.updateTimer)
        }
      }
    case .stopTimer:
      timer?.invalidate()
      timer = nil
    default:
      break
    }
    
    next(action)
  }
}

let timerMiddleware = AnyMiddleware(TimerMiddleware())
