//


import Foundation
import TinyRedux


enum Sample03Actions: ReduxAction {
  case setHeader(String)
  case setMessage(String)
}

extension Sample03Actions: Identifiable {
  var id: Int {
    switch self {
    case .setHeader: 1
    case .setMessage: 2
    }
  }
}

extension Sample03Actions: CustomStringConvertible {
  var description: String {
    switch self {
    case .setHeader: "setHeader"
    case .setMessage: "setMessage"
      
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

