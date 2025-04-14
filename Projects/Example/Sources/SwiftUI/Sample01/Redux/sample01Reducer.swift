//


import Foundation
import TinyRedux


@MainActor
let sample01Reducer = Reducer<AppState, AppActions>(id: "sample01Reducer") { state, context in
  let action = context.action
  
  switch action {
  case .insertDate:
    context.handled()
    state.dates.append(Date.now)
  case .removeDate:
    context.handled()
    if !state.dates.isEmpty {
      state.dates.removeLast()
    }
  default:
    break
  }
}
