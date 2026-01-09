//


import Foundation
import TinyRedux


@MainActor
let sample01Reducer = Reducer<AppState, AppActions>(id: "sample01Reducer") { context in
  
  let (state, action, _) = context
  
  switch action {
  case .insertDate:
    state.dates.append(Date.now)
  case .removeDate:
    if !state.dates.isEmpty {
      state.dates.removeLast()
    }
  default:
    break
  }
}
