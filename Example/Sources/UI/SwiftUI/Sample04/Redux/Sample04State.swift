//


import Observation
import TinyRedux


@Observable
@MainActor
final class Sample04State: ReduxState {
  var effectMessage: String
  var effectIsRunning: Bool
  var effectAlertMessage: String?
  var effectAlertPresented: Bool

  @ObservationIgnored
  lazy var readOnly = ReadOnly(self)

  init(
    effectMessage: String = "Tap Run Effect to start.",
    effectIsRunning: Bool = false,
    effectAlertMessage: String? = nil,
    effectAlertPresented: Bool = false
  ) {
    self.effectMessage = effectMessage
    self.effectIsRunning = effectIsRunning
    self.effectAlertMessage = effectAlertMessage
    self.effectAlertPresented = effectAlertPresented
  }
}

extension Sample04State {
  @Observable
  @MainActor
  final class ReadOnly: ReduxReadOnlyState, @unchecked Sendable {
    private unowned let state: Sample04State
    init(_ state: Sample04State) { self.state = state }
  }
}

extension Sample04State.ReadOnly {
  var effectMessage: String { state.effectMessage }
  var effectIsRunning: Bool { state.effectIsRunning }
  var effectAlertMessage: String? { state.effectAlertMessage }
  var effectAlertPresented: Bool { state.effectAlertPresented }
}
