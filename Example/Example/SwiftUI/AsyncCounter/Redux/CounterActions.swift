//


import Foundation


enum CounterActions {
  case increaseCounter
  case decreaseCounter
}

extension AppActions {
  var counter: CounterActions? {
    get { if case .counter(let value) = self { value } else { nil } }
    set { if case .counter = self, let newValue { self = .counter(newValue) } else { return } }
  }
}
