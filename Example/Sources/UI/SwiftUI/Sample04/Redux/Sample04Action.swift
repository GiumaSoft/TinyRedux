//


import Foundation
import TinyRedux


@CaseID
enum Sample04Action: ReduxAction {
  case runEffectDemo
  case runEffectDemoFailure
  case setEffectMessage(String)
  case setEffectRunning(Bool)
  case setEffectAlertMessage(String)
  case setEffectAlertPresented(Bool)
}

extension Sample04Action: CustomStringConvertible,
                          CustomDebugStringConvertible {
  
  var description: String { id }
  var debugDescription: String {
    switch self {
    case .runEffectDemo: "runEffectDemo"
    case .runEffectDemoFailure: "runEffectDemoFailure"
    case .setEffectMessage(let message): "setEffectMessage \(message)"
    case .setEffectRunning(let isRunning): "setEffectRunning \(isRunning)"
    case .setEffectAlertMessage(let message): "setEffectAlertMessage \(message)"
    case .setEffectAlertPresented(let isPresented): "setEffectAlertPresented \(isPresented)"
    }
  }
}
