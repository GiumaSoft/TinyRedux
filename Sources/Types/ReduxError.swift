

import Foundation


enum ReduxError<S, A>: Error where S : ReduxState, A : ReduxAction {
  case storeDeallocated
  
}

extension ReduxError: CustomStringConvertible {
  ///
  var description: String {
    switch self {
    case .storeDeallocated:
      "Store<\(S.self)),\(A.self)> was deallocated while processing an action. Store is expected to exists for the entire App lifecycle."
    }
  }
}
