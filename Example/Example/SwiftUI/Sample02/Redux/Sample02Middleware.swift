//

import Foundation
import TinyRedux

final class Sample02Middleware: Middleware {
  private var timer: Timer?
  
  func run(_ args: RunArguments<Sample02State, Sample02Actions>) {
    print("Entering Sample02 Middleware...")
    
    let (_, dispatch, next, action) = args
    
    switch action {
    case .startTimer:
      if timer == nil {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
          if timer.isValid {
            dispatch(.increase)
          }
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

let sample02Middleware = AnyMiddleware(Sample02Middleware())
