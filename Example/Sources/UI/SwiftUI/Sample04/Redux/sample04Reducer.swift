//

import Foundation
import TinyRedux

@MainActor
let sample04Reducer = AnyReducer<Sample04State, Sample04Action>(id: "sample04Reducer") { context in
  let (state, action) = context.args

  switch action {
  case .setEffectMessage(let message):
    state.effectMessage = message
    return .next
  case .setEffectRunning(let isRunning):
    state.effectIsRunning = isRunning
    return .next
  case .setEffectAlertMessage(let message):
    state.effectAlertMessage = message
    return .next
  case .setEffectAlertPresented(let isPresented):
    state.effectAlertPresented = isPresented
    return .next
  default:
    return .defaultNext
  }
}
