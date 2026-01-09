//


import Foundation
import TinyRedux


let uiKitSample01Reducer = AnyReducer<UIKitSample01State, UIKitSample01Action>(id: "uiKitSample01Reducer") { context in

  let (state, action) = context.args

  switch action {
  ///
  case .insertDate:
    state.dates.append(Date.now)

    return .next
  ///
  case .removeDate:
    if !state.dates.isEmpty {
      state.dates.removeLast()

      return .next
    }

    return .defaultNext
  }
}
