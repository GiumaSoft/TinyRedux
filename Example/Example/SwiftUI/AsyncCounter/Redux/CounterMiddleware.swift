//

import Foundation
import TinyRedux

final class AsyncCounterMiddleware: Middleware {
  
  func run(_ args: RunArguments<CounterState, CounterActions>) {
    print("Entering AsyncCounterMiddleware...")
    
    let (getState, _, next, action) = args
    
    switch action {
    case .increaseCounter:
      Task.detached(priority: .background) {
        try await Task.sleep(for: .seconds(2))
        next(.increaseCounter)
      }
      //next(.proceed)
      return
    case .decreaseCounter:
      if getState().counter == 0 {
        print("State counter is already 0.")
        return
      }
    default:
      break
    }
    
    next(action)
  }
}

let counterMiddleware = AnyMiddleware(AsyncCounterMiddleware())
