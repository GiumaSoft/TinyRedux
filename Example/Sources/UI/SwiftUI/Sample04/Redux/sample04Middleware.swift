//

import Foundation
import TinyRedux

private enum Sample04Error: Error {
  case demoFailure
}

@MainActor
let sample04Middleware = AnyMiddleware<AppState, AppActions>(id: "sample04Middleware") { context in
  let (dispatch, resolve, task, next, action) = context.args
  
  switch action {
  case .runEffectDemo:
    dispatch(0, .setEffectRunning(true), .setEffectMessage("Running async effect..."))

    task { _ in
      try await Task.sleep(nanoseconds: 1_000_000_000)
      let timestamp = Date().formatted(date: .abbreviated, time: .standard)
      dispatch(0, .setEffectMessage("Completed at \(timestamp)"), .setEffectRunning(false))
      context.complete()
    }

    return
  case .runEffectDemoFailure:
    dispatch(0,
      .setEffectRunning(true),
      .setEffectMessage("Running failing effect...")
    )

    task { _ in
      do {
        try await Task.sleep(nanoseconds: 5_000_000_000)
        throw Sample04Error.demoFailure
      } catch {
        dispatch(0,
          .setEffectMessage("Failed. Check logs for details."),
          .setEffectRunning(false)
        )
        context.complete()
        throw error
      }
    }
    
    return
  default:
    break
  }

  try next(action)
}
