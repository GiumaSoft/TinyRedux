//


import Foundation
import TinyRedux


@CaseID
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
