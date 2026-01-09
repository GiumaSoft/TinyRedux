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
  case runEffectDemo
  case runEffectDemoFailure
  case setEffectMessage(String)
  case setEffectRunning(Bool)
  case setEffectAlertMessage(String)
  case setEffectAlertPresented(Bool)
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
    case .runEffectDemo: "runEffectDemo"
    case .runEffectDemoFailure: "runEffectDemoFailure"
    case .setEffectMessage: "setEffectMessage"
    case .setEffectRunning: "setEffectRunning"
    case .setEffectAlertMessage: "setEffectAlertMessage"
    case .setEffectAlertPresented: "setEffectAlertPresented"
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
    case .setEffectMessage(let message): "setEffectMessage \(message)"
    case .setEffectRunning(let isRunning): "setEffectRunning \(isRunning)"
    case .setEffectAlertMessage(let message): "setEffectAlertMessage \(message)"
    case .setEffectAlertPresented(let isPresented): "setEffectAlertPresented \(isPresented)"
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
    case .runEffectDemo: 60
    case .runEffectDemoFailure: 70
    case .setEffectMessage: 80
    case .setEffectRunning: 90
    case .setEffectAlertMessage: 100
    case .setEffectAlertPresented: 110
    case .startAutoCounter: 120
    case .stopAutoCounter: 130
    }
  }
}

extension AppActions: Hashable {
  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}
