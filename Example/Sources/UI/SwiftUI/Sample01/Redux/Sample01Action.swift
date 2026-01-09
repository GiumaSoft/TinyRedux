//


import Foundation
import TinyRedux


@CaseID
enum Sample01Action: ReduxAction {
  case insertDate
  case removeDate
}

extension Sample01Action: CustomDebugStringConvertible {
  var debugDescription: String { id }
}
