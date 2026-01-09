//


import Foundation
import TinyRedux


func reduxLogFormatter<S, A>(_ log: Store<S, A>.Log) -> String? where S : ReduxState, A : ReduxAction & CustomDebugStringConvertible {
  let logMessage: String? = switch log {
  case .middleware(_, _, _, .defaultNext):
    nil
  case let .middleware(id, action, elapsed, .next),
       let .middleware(id, action, elapsed, .nextAs),
       let .middleware(id, action, elapsed, .exit(.success)):
    "ℹ️ [[ MIDDLEWARE ]] \(id) processed action .\(action.debugDescription) (\(elapsed.fmt()))."
  case let .middleware(id, action, elapsed, _):
    "🚫 [[ MIDDLEWARE ]] \(id) failed to process action .\(action.debugDescription) (\(elapsed.fmt()))."
  case let .reducer(id, action, elapsed, exit) where exit == .next:
    "ℹ️ [[ REDUCER ]] \(id) reduced action .\(action.debugDescription) (\(elapsed.fmt()))."
  case let .resolver(id, action, elapsed, .exit(.success), error),
       let .resolver(id, action, elapsed, .reduce, error),
       let .resolver(id, action, elapsed, .reduceAs(_), error):
    "ℹ️ [[ RESOLVER ]] \(id) resolved error \"\(error)\" (Error, .\(action.debugDescription), \(elapsed.fmt()))."
  case let .resolver(id, action, elapsed, _, error):
    "🚫 [[ RESOLVER ]] \(id) failed to resolve error \"\(error)\" (Error, .\(action.debugDescription), \(elapsed.fmt()))."
  case .store(let message):
    "ℹ️ [[ STORE ]] \(message)"
  default:
    nil
  }
  return logMessage
}
