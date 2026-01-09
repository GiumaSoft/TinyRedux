//


import Foundation
import TinyRedux


@MainActor
let sample03Reducer = Reducer<AppState, AppActions>(id: "sample03Reducer") { context in
  
  let (state, action, _) = context
  
  switch action {
  case .setHeader(let header):
    state.header = header
    context.complete()
  case .setMessage(let message):
    state.message = message
    context.complete()
  default:
    break
  }
}
