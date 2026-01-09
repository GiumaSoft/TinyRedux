//


import Foundation
import TinyRedux


@CaseID
enum Sample03Action: ReduxAction {
  case setHeader(String)
  case setMessage(String)
}

extension Sample03Action: CustomStringConvertible,
                          CustomDebugStringConvertible {
  
  var description: String { id }
  var debugDescription: String {
    switch self {
    case .setHeader(let header): "setHeader \(header)"
    case .setMessage(let message): "setMessage \(message)"
    }
  }
}
