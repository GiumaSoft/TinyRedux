//

import Foundation
import TinyRedux


final class Sample02MiddlewareModel {
  private var timer: Timer?
  
  func startTimer(_ timeInterval: TimeInterval, block: @escaping () -> Void) {
    if timer == nil {
      self.timer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: true) { timer in
        guard timer.isValid else { return }
        block()
      }
    }
  }
  
  func stopTimer() {
    timer?.invalidate()
    timer = nil
  }
}

let sample02Middleware = StatedMiddleware<Sample02MiddlewareModel, Sample02State, Sample02Actions>(model: Sample02MiddlewareModel()) { model, args in
  print("Entering Sample02 Middleware...")
  
  let (_, dispatch, next, action) = args
  
  switch action {
  case .startTimer:
    model.startTimer(1) {
      dispatch(.increase)
    }
  case .stopTimer:
    model.stopTimer()
  default:
    break
  }
  
  next(action)
}
