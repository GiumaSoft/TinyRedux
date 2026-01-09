//


import Foundation
import TinyRedux


func reduxLogFormatter<S, A>(_ log: Store<S, A>.Log) -> String where S : ReduxState, A : ReduxAction {
  let logMessage = switch log {
  case let .middleware(id, action, elapsed, .failure(error)):
    "🚫 [[ MIDDLEWARE ]] \(id) thrown error \"\(error)\" for .\(action.debugDescription) (\(elapsed.fmt()))."
  case let .middleware(id, action, elapsed, .success(succeeded)) where succeeded == true:
    "ℹ️ [[ MIDDLEWARE ]] \(id) processed action .\(action.debugDescription) (\(elapsed.fmt()))."
  case let .middleware(id, action, elapsed, .success(succeeded)) where succeeded == false:
    "🚫 [[ MIDDLEWARE ]] \(id) failed to process action .\(action.debugDescription) (\(elapsed.fmt()))."
  case .reducer(let id, let action, let elapsed, let succeeded) where succeeded == true:
    "ℹ️ [[ REDUCER ]] \(id) reduced action .\(action.debugDescription) (\(elapsed.fmt()))."
  case .reducer(let id, let action, let elapsed, let succeeded) where succeeded == false:
    "🚫 [[ REDUCER ]] \(id) failed to reduce .\(action.debugDescription) (\(elapsed.fmt()))."
  case .resolver(let id, let action, let elapsed, let succeeded, let error) where succeeded == true:
    "ℹ️ [[ RESOLVER ]] \(id) resolved error \"\(error)\" (Error, .\(action.debugDescription), \(elapsed.fmt()))."
  case .resolver(let id, let action, let elapsed, let succeeded, let error) where succeeded == false:
    "🚫 [[ RESOLVER ]] \(id) failed to resolve error \"\(error)\" (Error, .\(action.debugDescription), \(elapsed.fmt()))."
  case .store(let message):
    "ℹ️ [[ STORE ]] \(message)"
  default:
    "[[ REDUX ]] unmanaged log condition."
  }
  return logMessage
}
