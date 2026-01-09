//


import Foundation
import Observation
import TinyRedux


@Observable
@MainActor
final class Sample01State: ReduxState {
  var dates: Array<Date>

  @ObservationIgnored
  lazy var readOnly = ReadOnly(self)

  init(dates: Array<Date> = [Date.now]) {
    self.dates = dates
  }
}

extension Sample01State {
  @Observable
  @MainActor
  final class ReadOnly: ReduxReadOnlyState, @unchecked Sendable {
    private unowned let state: Sample01State
    init(_ state: Sample01State) { self.state = state }
  }
}

extension Sample01State.ReadOnly {
  var dates: Array<Date> { state.dates }
}
