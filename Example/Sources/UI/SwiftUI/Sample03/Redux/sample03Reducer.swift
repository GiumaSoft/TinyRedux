//


import Foundation
import TinyRedux


@MainActor
let sample03Reducer = AnyReducer<Sample03State, Sample03Action>(id: "sample03Reducer") { context in

  let (state, action) = context.args

  switch action {
  case .setHeader(let header):
    state.header = header
    return .next
  case .setMessage(let message):
    state.message = message
    return .next
  }
}
