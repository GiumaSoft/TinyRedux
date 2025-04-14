//


import Foundation
import TinyRedux


@MainActor
let sample03Reducer = Reducer<AppState, AppActions>(id: "sample03Reducer") { state, context in
  let action = context.action
  
  switch action {
  case .setHeader(let header):
    context.handled()
    state.header = header
  case .setMessage(let message):
    context.handled()
    state.message = message
  default:
    break
  }
}
