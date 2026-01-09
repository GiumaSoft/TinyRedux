//


import Foundation
import Observation
import TinyRedux


@ReduxState
@Observable
final class UIKitSample01State: ReduxState {
  var dates: Array<Date>
}
