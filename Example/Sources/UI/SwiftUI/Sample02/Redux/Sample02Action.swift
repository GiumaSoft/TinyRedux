//


import Foundation
import TinyRedux


@CaseID
enum Sample02Action: ReduxAction {
  case decrease
  case increase
  case startAutoCounter
  case stopAutoCounter
}

extension Sample02Action: CustomDebugStringConvertible {
  var debugDescription: String { id }
}
