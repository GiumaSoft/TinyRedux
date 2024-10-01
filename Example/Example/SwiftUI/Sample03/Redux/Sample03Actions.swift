//


import Foundation


enum Sample03Actions {
  case setHeader(String)
  case setMessage(String)
}

extension Sample03Actions: Equatable {
  static func == (lhs: Sample03Actions, rhs: Sample03Actions) -> Bool {
    switch (lhs, rhs) {
    case (.setHeader, .setHeader),
         (.setMessage, .setMessage):
          true
    default:
          false
    }
  }
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

