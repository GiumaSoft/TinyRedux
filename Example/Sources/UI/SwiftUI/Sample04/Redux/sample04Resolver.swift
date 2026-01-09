//

import Foundation
import TinyRedux

@MainActor
let sample04Resolver = AnyResolver<AppState, AppActions>(id: "sample04Resolver") { context in
  let (_, dispatch, next, origin, error, action) = context.args

  switch origin {
  case .middleware(let id) where id == "sample04Middleware":
    switch (error, action) {
    default:
      let message = "Resolver caught: \(String(describing: error))"
      dispatch(0,
        .setEffectAlertMessage(message),
        .setEffectAlertPresented(true),
        .setEffectRunning(false)
      )
      context.complete()
    }
    
  default:
    
    break
  }
  
  next(error, action)
}
