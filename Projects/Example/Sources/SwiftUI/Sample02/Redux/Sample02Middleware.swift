//

import Foundation
import TinyRedux


actor Sample02Coordinator {
  var isRunning: Bool = false

  func startAutoCounter() { isRunning = true }
  func stopAutoCounter() { isRunning = false }
}

let sample02Middleware = StatedMiddleware<Sample02Coordinator, Sample02State, Sample02Actions>(coordinator: Sample02Coordinator()) { coordinator, args in
  print("Entering Sample02 Middleware...")
  print("Running on thread: \(Thread.currentThread)")
  
  let (_, dispatch, next, action) = args
  
  switch action {
  case .startAutoCounter:
    if await !coordinator.isRunning {
      await coordinator.startAutoCounter()
      Task.detached(priority: .background) {
        while await coordinator.isRunning {
          print("Running on thread: \(Thread.currentThread)")
          try await Task.sleep(nanoseconds: 100_000_000)
          dispatch(.increase)
        }
      }
    }
  case .stopAutoCounter:
    await coordinator.stopAutoCounter()
  default:
    break
  }
  
  try await next(action)
}
