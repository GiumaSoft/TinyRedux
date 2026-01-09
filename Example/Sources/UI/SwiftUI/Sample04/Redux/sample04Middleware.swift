//

import Foundation
import TinyRedux

private enum Sample04Error: Error {
  case demoFailure
}

@MainActor
let sample04Middleware = AnyMiddleware<Sample04State, Sample04Action>(id: "sample04Middleware") { context in
  let (_, dispatch, action) = context.args

  switch action {
  case .runEffectDemo:
    dispatch(0, .setEffectRunning(true), .setEffectMessage("Running async effect..."))

    return .task { _ in
      try await Task.sleep(nanoseconds: 1_000_000_000)
      let timestamp = Date().formatted(date: .abbreviated, time: .standard)
      dispatch(0, .setEffectMessage("Completed at \(timestamp)"), .setEffectRunning(false))
    }

  case .runEffectDemoFailure:
    dispatch(0,
      .setEffectRunning(true),
      .setEffectMessage("Running failing effect...")
    )

    return .task { _ in
      try await Task.sleep(nanoseconds: 5_000_000_000)
      throw Sample04Error.demoFailure
    }

  default:
    return .defaultNext
  }
}
