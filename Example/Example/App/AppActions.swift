//


import Foundation


enum AppActions {
  case sample01(Sample01Actions)
  case sample02(Sample02Actions)
  case sample03(Sample03Actions)
}

extension AppActions: Equatable {
  static func == (lhs: AppActions, rhs: AppActions) -> Bool {
    switch (lhs, rhs) {
    case (.sample01(let left), .sample01(let right)):
      left == right
    case (.sample02(let left), .sample02(let right)):
      left == right
    case (.sample03(let left), .sample03(let right)):
      left == right
    default:
      false
    }
  }
}
