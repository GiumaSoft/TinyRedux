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
}

@MainActor
protocol ReadOnlyAppState: Sendable {
  var dates: Array<Date> { get }
  var header: String { get }
  var message: String { get }
  var counter: Int { get }
  var counterMessage: String { get }
  var timeCount: Int { get }
  var timerIsRunning: Bool { get }
  var uuid: String { get }
  var uuidColor: Color { get }
  var pad: Int? { get }
}

extension AppState: ReadOnlyAppState {
  var readOnly: ReadOnlyAppState {
    self
  }
}
