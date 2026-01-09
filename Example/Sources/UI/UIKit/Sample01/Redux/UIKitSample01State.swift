//


import Foundation
import Observation
import TinyRedux


@Observable
@MainActor
final class UIKitSample01State: ReduxState {
  var dates: Array<Date>

  @ObservationIgnored
  lazy var readOnly = ReadOnly(self)

  init(dates: Array<Date> = [Date.now]) {
    self.dates = dates
  }
}

extension UIKitSample01State {
  @Observable
  @MainActor
  final class ReadOnly: ReduxReadOnlyState, @unchecked Sendable {
    private unowned let state: UIKitSample01State
    init(_ state: UIKitSample01State) { self.state = state }
  }
}

extension UIKitSample01State.ReadOnly {
  var dates: Array<Date> { state.dates }
}
