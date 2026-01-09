//


import Foundation
import TinyRedux


@CaseID
enum UIKitSample01Action: ReduxAction {
  case insertDate
  case removeDate
}

extension UIKitSample01Action: CustomStringConvertible,
                               CustomDebugStringConvertible {
  
  var description: String { id }
  var debugDescription: String { id }
}
