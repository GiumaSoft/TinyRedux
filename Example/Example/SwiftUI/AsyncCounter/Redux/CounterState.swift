//


import Foundation


typealias CounterState = (
  counter: Int,
  counterMessage: String
)

extension AppState {
  var counterState: CounterState {
    get {
      CounterState(
        self.counter,
        self.counterMessage
      )
    }
    set {
      (
        self.counter,
        self.counterMessage
      ) = newValue
    }
  }
}

