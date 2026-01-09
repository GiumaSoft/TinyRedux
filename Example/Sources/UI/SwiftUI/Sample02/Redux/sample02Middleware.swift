//

import Combine
import Foundation
import TinyRedux


@MainActor
let sample02Middleware = StatedMiddleware<Sample02State, Sample02Action>(id: "Sample02Middleware", coordinator: Sample02Coordinator()) { coordinator, context in

  let (_, dispatch, action) = context.args

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
    return .next
  case .stopAutoCounter:
    coordinator.cancellables.removeAll()
    return .next
  default:
    return .defaultNext
  }
}


final class Sample02Coordinator: @unchecked Sendable {
  var cancellables: Set<AnyCancellable> = []
}
