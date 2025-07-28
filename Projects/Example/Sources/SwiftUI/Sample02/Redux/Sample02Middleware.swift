//

import Combine
import Foundation
import TinyRedux




@MainActor
final class Sample02Coordinator {
  var cancellables: Set<AnyCancellable> = []
}

@MainActor
let sample02Middleware = StatedMiddleware<Sample02Coordinator, AppState, Sample02Actions>(coordinator: Sample02Coordinator()) { coordinator, context in
  let (_, dispatch, asyncDispatch, next, asyncNext, action) = context.args
  
  switch action {
  case .startAutoCounter:
    if coordinator.cancellables.isEmpty {
      Timer.publish(every: 1.0, on: .main, in: .common)
        .autoconnect()
        .sink { _ in
          dispatch(.increase)
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
