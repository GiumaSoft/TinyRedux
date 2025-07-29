//


import Foundation
import TinyRedux


@MainActor
let sample03Reducer = Reducer<AppState, Sample03Actions> { state, action in
  switch action {
  case .setHeader(let header):
    state.header = header
  case .setMessage(let message):
    state.message = message
  }
}
