//


import Foundation
import TinyRedux


@MainActor
let bindingReducer = Reducer<BindingState, BindingActions> { state, action in
  switch action {
  case .setHeader(let header):
    state.header = header
  case .setMessage(let message):
    state.message = message
  }
}
