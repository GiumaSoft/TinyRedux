//


import Foundation


enum Sample02Actions: Equatable {
  case increase
  case decrease
  case startTimer
  case stopTimer
  case none
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
