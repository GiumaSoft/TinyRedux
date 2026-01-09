//

import Combine
import Foundation
import TinyRedux


@MainActor
let sample02Middleware = StatedMiddleware<AppState, AppActions>(id: "Sample02Middleware", coordinator: Sample02Coordinator()) { coordinator, context in
  
  let (dispatch, resolve, task, next, action) = context.args
  
  switch action {
  case .startAutoCounter:
    if coordinator.cancellables.isEmpty {
      Timer.publish(every: 1.0, on: .main, in: .common)
        .autoconnect()
        .sink { @Sendable _ in
          dispatch(0, .increase)
        }
        .store(in: &coordinator.cancellables)
    }
    context.complete()
  case .stopAutoCounter:
    coordinator.cancellables.removeAll()
    context.complete()
  default:
    break
  }
  
  try next(action)
}


final class Sample02Coordinator: @unchecked Sendable {
  var cancellables: Set<AnyCancellable> = []
}
