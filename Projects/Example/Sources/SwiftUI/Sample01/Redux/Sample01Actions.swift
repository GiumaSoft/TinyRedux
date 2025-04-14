//


import Foundation


enum Sample01Actions: Sendable & Equatable {
  case insertDate
  case removeDate
}

extension AppActions {
  var sample01: Sample01Actions? {
    get {
      switch self {
      case .sample01(let action):
        action
      default:
        nil
      }
    }
    set {
      switch self {
      case .sample01(let action):
        self = .sample01(action)
      default:
        break
      }
    }
  }
}
