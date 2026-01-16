//

import Foundation
import TinyRedux

@MainActor
let sample04Resolver = Resolver<AppState, AppActions>(id: "sample04Resolver") { context in
  let (_, dispatch, error, action, origin, next) = context.args
  
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
      
      break
    }
    
  default:
    
    break
  }
  
  next(error, action)
}
