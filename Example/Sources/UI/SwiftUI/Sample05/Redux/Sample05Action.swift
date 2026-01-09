//


import Foundation
import TinyRedux


@CaseID
enum Sample05Action: ReduxAction {
  case incXRotation
  case incYRotation
  case incZRotation
}

extension Sample05Action: CustomStringConvertible,
                          CustomDebugStringConvertible {
  
  var description: String { id }
  var debugDescription: String { id }
}
