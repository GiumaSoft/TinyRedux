//


import Observation
import TinyRedux


@Observable
@MainActor
final class Sample02State: ReduxState {
  var timeCount: Int
  var timerIsRunning: Bool

  @ObservationIgnored
  lazy var readOnly = ReadOnly(self)

  init(timeCount: Int = 0, timerIsRunning: Bool = false) {
    self.timeCount = timeCount
    self.timerIsRunning = timerIsRunning
  }
}

extension Sample02State {
  @Observable
  @MainActor
  final class ReadOnly: ReduxReadOnlyState, @unchecked Sendable {
    private unowned let state: Sample02State
    init(_ state: Sample02State) { self.state = state }
  }
}

extension Sample02State.ReadOnly {
  var timeCount: Int { state.timeCount }
  var timerIsRunning: Bool { state.timerIsRunning }
}
