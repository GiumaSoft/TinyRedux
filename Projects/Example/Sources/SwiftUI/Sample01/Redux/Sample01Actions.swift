//


import Foundation
import TinyRedux


enum Sample01Actions: ReduxAction {
  case insertDate
  case removeDate
}

extension Sample01Actions: Identifiable {
  var id: Int {
    switch self {
    case .insertDate: 1
    case .removeDate: 2
    }
  }
}

extension Sample01Actions: CustomStringConvertible {
  var description: String {
    switch self {
    case .insertDate: "insertDate"
    case .removeDate: "removeDate"
    }
  }
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
