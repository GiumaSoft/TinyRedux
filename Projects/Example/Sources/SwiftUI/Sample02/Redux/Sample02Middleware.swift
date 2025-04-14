//

import Combine
import Foundation
import TinyRedux




@MainActor
final class Sample02Coordinator {
  var cancellables: Set<AnyCancellable> = []
}

let sample02Middleware = StatedMiddleware<Sample02Coordinator, AppState, Sample02Actions>(coordinator: Sample02Coordinator()) { c, args in
  let (_, dispatch, next, action) = args
  
  switch action {
  case .startAutoCounter:
    if c.cancellables.isEmpty {
      Timer.publish(every: 1.0, on: .main, in: .common)
        .autoconnect()
        .sink { _ in
          dispatch(.increase, 0)
        }
        .store(in: &c.cancellables)
    }
    
    break
  case .stopAutoCounter:
    c.cancellables.removeAll()
    
    break
  default:
    break
  }
  
  try next(action)
}
