//


import Observation
import TinyRedux


@Observable
@MainActor
final class Sample03State: ReduxState {
  var header: String
  var message: String

  @ObservationIgnored
  lazy var readOnly = ReadOnly(self)

  nonisolated
  init(
    header: String = "Lorem ipsum",
    message: String = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nullam eu fringilla libero, sed euismod ipsum."
  ) {
    self._header = header
    self._message = message
  }
}

extension Sample03State {
  @Observable
  @MainActor
  final class ReadOnly: ReduxReadOnlyState, @unchecked Sendable {
    private unowned let state: Sample03State
    init(_ state: Sample03State) { self.state = state }
  }
}

extension Sample03State.ReadOnly {
  var header: String { state.header }
  var message: String { state.message }
}
