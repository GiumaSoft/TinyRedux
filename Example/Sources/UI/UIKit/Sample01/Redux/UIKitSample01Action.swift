//


import Foundation
import TinyRedux


@CaseID
enum UIKitSample01Action: ReduxAction {
  case insertDate
  case removeDate
}

extension UIKitSample01Action: CustomDebugStringConvertible {
  var debugDescription: String { id }
}
