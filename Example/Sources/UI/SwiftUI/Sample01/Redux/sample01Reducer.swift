//


import Foundation
import TinyRedux


@MainActor
let sample01Reducer = AnyReducer<Sample01State, Sample01Action>(id: "sample01Reducer") { context in

  let (state, action) = context.args

  switch action {
  case .insertDate:
    state.dates.append(Date.now)
    return .next
  case .removeDate:
    if !state.dates.isEmpty {
      state.dates.removeLast()
      return .next
    }
    return .defaultNext
  }
}
