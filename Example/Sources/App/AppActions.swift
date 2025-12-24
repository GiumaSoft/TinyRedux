//


import Foundation
import TinyRedux


enum AppActions: ReduxAction {
  case decrease
  case increase
  case insertDate
  case removeDate
  case setHeader(String)
  case setMessage(String)
  case startAutoCounter
  case stopAutoCounter
}

extension AppActions: CustomStringConvertible {
  var description: String {
    switch self {
    case .decrease: "decrese"
    case .increase: "increase"
    case .insertDate: "insertDate"
    case .removeDate: "removeDate"
    case .setHeader: "setHeader"
    case .setMessage: "setMessage"
    case .startAutoCounter: "startAutoCounter"
    case .stopAutoCounter: "stopAutoCounter"
    }
  }
}

extension AppActions: CustomDebugStringConvertible {
  var debugDescription: String {
    switch self {
    case .setHeader(let header): "setHeader \(header)"
    case .setMessage(let message): "setMessage \(message)"
    default:
      description
    }
  }
}

extension AppActions: Equatable {
  
}

extension AppActions: Identifiable {
  var id: Int {
    switch self {
    case .decrease: 0
    case .increase: 10
    case .insertDate: 20
    case .removeDate: 30
    case .setHeader: 40
    case .setMessage: 50
    case .startAutoCounter: 60
    case .stopAutoCounter: 70
    }
  }
}

extension AppActions: Hashable {
  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}


