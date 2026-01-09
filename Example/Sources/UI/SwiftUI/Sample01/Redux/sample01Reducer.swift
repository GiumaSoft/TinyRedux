//


import Foundation
import TinyRedux


@MainActor
let sample01Reducer = AnyReducer<AppState, AppActions>(id: "sample01Reducer") { context in
  
  let (state, action) = context.args
  
  switch context.action {
  case .insertDate:
    state.dates.append(Date.now)
    context.complete()
  case .removeDate:
    if !state.dates.isEmpty {
      state.dates.removeLast()
      context.complete()
    }
  default:
    break
  }
}
