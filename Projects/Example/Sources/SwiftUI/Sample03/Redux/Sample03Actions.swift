//


import Foundation


enum Sample03Actions: Sendable & Equatable {
  case setHeader(String)
  case setMessage(String)
}

extension AppActions {
  var sample03: Sample03Actions? {
    get {
      if case .sample03(let value) = self {
        value
      } else {
        nil
      }
    }
    set {
      if case .sample03 = self, let newValue {
        self = .sample03(newValue)
      } else {
        return
      }
    }
  }
}

