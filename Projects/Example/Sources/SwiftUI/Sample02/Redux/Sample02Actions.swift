//


import Foundation
import TinyRedux


enum Sample02Actions: ReduxA {
  case increase
  case decrease
  case startAutoCounter
  case stopAutoCounter
}


extension Sample02Actions: Identifiable {
  var id: Int {
    switch self {
    case .increase: 1
    case .decrease: 2
    case .startAutoCounter: 3
    case .stopAutoCounter: 4
    }
  }
}

extension Sample02Actions: CustomStringConvertible {
  var description: String {
    switch self {
    case .increase: "increase"
    case .decrease: "decrease"
    case .startAutoCounter: "startAutoCounter"
    case .stopAutoCounter: "stopAutoCounter"
      
    }
  }
}


extension AppActions {
  var sample02: Sample02Actions? {
    get {
      switch self {
      case .sample02(let action):
        action
      default:
        nil
      }
    }
    set {
      switch self {
      case .sample02(let action):
        self = .sample02(action)
      default:
        break
      }
    }
  }
}
