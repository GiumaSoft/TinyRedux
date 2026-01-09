//

import Foundation
import TinyRedux

@MainActor
let sample04Resolver = AnyResolver<AppState, AppActions>(id: "sample04Resolver") { context in
  let (_, dispatch, next, origin, error, action) = context.args

  if origin == "sample04Middleware" {
    let message = "Resolver caught: \(String(describing: error))"
    dispatch(0,
      .setEffectAlertMessage(message),
      .setEffectAlertPresented(true),
      .setEffectRunning(false)
    )
    context.complete()
  }
  
  next(error, action)
}
