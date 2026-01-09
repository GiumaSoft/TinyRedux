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

extension Sample02Action: CustomStringConvertible,
                          CustomDebugStringConvertible {
  
  var description: String { id }
  var debugDescription: String { id }
}
