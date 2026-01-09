

import Foundation


/// Errors emitted by TinyRedux components.
public enum ReduxError: Error {
  /// Store was deallocated while processing an action.
  case storeDeallocated(Any.Type, Any.Type)
}

extension ReduxError: CustomStringConvertible {
  /// A human-readable description of the error.
  public var description: String {
    switch self {
    case .storeDeallocated(let state, let action):
      "Store<\(state), \(action)> was deallocated while processing an action."
    }
  }
}
