//


import Foundation
import TinyRedux


enum AppActions: ReduxAction {
  case sample01(Sample01Actions)
  case sample02(Sample02Actions)
  case sample03(Sample03Actions)
}

extension AppActions: Identifiable {
  var id: Int {
    switch self {
    case .sample01(let action): 0 + action.id
    case .sample02(let action): 100 + action.id
    case .sample03(let action): 200 + action.id
    }
  }
}

extension AppActions: Hashable {
  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}

extension AppActions: CustomStringConvertible {
  var description: String {
    switch self {
    case .sample01(let action): "sample01.\(action)"
    case .sample02(let action): "sample02.\(action)"
    case .sample03(let action): "sample03.\(action)"
    }
  }
}
