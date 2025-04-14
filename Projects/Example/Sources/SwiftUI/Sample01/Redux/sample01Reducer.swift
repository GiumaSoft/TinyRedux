//


import Foundation
import TinyRedux


let sample01Reducer = Reducer<Sample01State, Sample01Actions> { state, action in
  print("Entering counterReducer")
  switch action {
  case .insertDate:
    state.append(Date.now)
  case .removeDate:
    if !state.isEmpty {
      state.removeLast()
    }
  }
}
