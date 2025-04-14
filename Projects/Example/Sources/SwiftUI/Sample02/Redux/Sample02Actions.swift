//


import Foundation


enum Sample02Actions: Sendable & Equatable {
  case increase
  case decrease
  case startAutoCounter
  case stopAutoCounter
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
