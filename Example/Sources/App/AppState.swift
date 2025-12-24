//


import Observation
import SwiftUI
import TinyRedux


@Observable
@MainActor
final class AppState: ReduxState {
  var dates: Array<Date>
  var header: String
  var message: String
  var counter: Int
  var counterMessage: String
  var timeCount: Int
  var timerIsRunning: Bool
  var uuid: String
  var uuidColor: Color
  var pad: Int?
  
  @ObservationIgnored
  lazy var readOnly = ReadOnlyAppState(self)

  init(
    dates: Array<Date>,
    header: String,
    message: String,
    counter: Int,
    counterMessage: String,
    timeCount: Int,
    timerIsRunning: Bool,
    uuid: String,
    uuidColor: Color,
    pad: Int? = nil
  ) {
    self.dates = dates
    self.header = header
    self.message = message
    self.counter = counter
    self.counterMessage = counterMessage
    self.timeCount = timeCount
    self.timerIsRunning = timerIsRunning
    self.uuid = uuid
    self.uuidColor = uuidColor
    self.pad = pad
  }
  
  convenience init() {
    self.init(
      dates: [Date.now],
      header: "Lorem ipsum",
      message: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nullam eu fringilla libero, sed euismod ipsum.",
      counter: 0,
      counterMessage: "",
      timeCount: 0,
      timerIsRunning: false,
      uuid: UUID().uuidString,
      uuidColor: Color.random,
      pad: nil
    )
  }
  
}

extension AppState {
  @MainActor
  final class ReadOnlyAppState: ReadOnlyState {
    private unowned let state: AppState
    init(_ state: AppState) {
      self.state = state
    }
  }
}

extension AppState.ReadOnlyAppState {
  var dates: Array<Date> { state.dates }
  var header: String { state.header }
  var message: String { state.message }
  var counter: Int { state.counter }
  var counterMessage: String { state.counterMessage }
  var timeCount: Int { state.timeCount }
  var timerIsRunning: Bool { state.timerIsRunning }
  var uuid: String { state.uuid }
  var uuidColor: Color { state.uuidColor }
  var pad: Int? { state.pad }
}
