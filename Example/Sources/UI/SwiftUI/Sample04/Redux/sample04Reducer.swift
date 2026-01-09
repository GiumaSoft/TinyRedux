//

import Foundation
import TinyRedux

@MainActor
let sample04Reducer = Reducer<AppState, AppActions>(id: "sample04Reducer") { context in
  let state = context.state

  switch context.action {
  case .setEffectMessage(let message):
    state.effectMessage = message
    context.complete()
  case .setEffectRunning(let isRunning):
    state.effectIsRunning = isRunning
    context.complete()
  case .setEffectAlertMessage(let message):
    state.effectAlertMessage = message
    context.complete()
  case .setEffectAlertPresented(let isPresented):
    state.effectAlertPresented = isPresented
    context.complete()
  default:
    break
  }
}
