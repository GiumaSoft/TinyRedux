//


import Foundation
import Observation
import TinyRedux


@Observable
@MainActor
final class Sample05State: ReduxState {
  var xRotation: Float
  var yRotation: Float
  var zRotation: Float

  @ObservationIgnored
  lazy var readOnly = ReadOnly(self)

  nonisolated
  init(xRotation: Float = 0, yRotation: Float = 0, zRotation: Float = 0) {
    self._xRotation = xRotation
    self._yRotation = yRotation
    self._zRotation = zRotation
  }
}

extension Sample05State {
  @Observable
  @MainActor
  final class ReadOnly: ReduxReadOnlyState, @unchecked Sendable {
    private unowned let state: Sample05State
    init(_ state: Sample05State) { self.state = state }
  }
}

extension Sample05State.ReadOnly {
  var xRotation: Float { state.xRotation }
  var yRotation: Float { state.yRotation }
  var zRotation: Float { state.zRotation }
}
