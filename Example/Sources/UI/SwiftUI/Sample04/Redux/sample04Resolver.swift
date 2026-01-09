//

import Foundation
import TinyRedux


let sample04Resolver = AnyResolver<Sample04State, Sample04Action>(id: "sample04Resolver") { context in
  let (_, dispatch, error, origin, action) = context.args

  if origin == "sample04Middleware" {
    let message = "Resolver caught: \(String(describing: error))"
    dispatch(0,
      .setEffectAlertMessage(message),
      .setEffectAlertPresented(true),
      .setEffectMessage("Failed. Check logs for details."),
      .setEffectRunning(false)
    )
    return .exit(.success)
  }

  return .defaultNext
}
