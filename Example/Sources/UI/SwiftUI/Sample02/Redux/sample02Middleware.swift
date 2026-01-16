//

import Combine
import Foundation
import TinyRedux


@MainActor
let sample02Middleware = StatedMiddleware<AppState, AppActions>(id: "Sample02Middleware", coordinator: Sample02Coordinator()) { coordinator, context in
  
  let (state, dispatch, next, action) = context.args
  
  switch action {
  case .startAutoCounter:
    if coordinator.cancellables.isEmpty {
      Timer.publish(every: 1.0, on: .main, in: .common)
        .autoconnect()
        .sink { _ in
          dispatch(0, .increase)
        }
        .store(in: &coordinator.cancellables)
    }
    
    break
  case .stopAutoCounter:
    coordinator.cancellables.removeAll()
    
    break
  default:
    break
  }
  
  try next(action)
}


@MainActor
final class Sample02Coordinator {
  var cancellables: Set<AnyCancellable> = []
}
