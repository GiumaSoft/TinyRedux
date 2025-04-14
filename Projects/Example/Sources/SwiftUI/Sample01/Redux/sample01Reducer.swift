//


import Foundation
import TinyRedux


let sample01Reducer = Reducer<AppState, Sample01Actions> { state, action in
  print("Entering counterReducer")
  switch action {
  case .insertDate:
    state.dates.append(Date.now)
  case .removeDate:
    if !state.dates.isEmpty {
      state.dates.removeLast()
    }
  }
}
