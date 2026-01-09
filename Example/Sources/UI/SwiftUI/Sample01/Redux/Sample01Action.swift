//


import Foundation
import TinyRedux


@CaseID
enum Sample01Action: ReduxAction {
  case insertDate
  case removeDate
}

extension Sample01Action: CustomStringConvertible,
                          CustomDebugStringConvertible {
  
  var description: String { id }
  var debugDescription: String { id }
}
