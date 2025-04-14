//


import SwiftUI


struct AppState: Sendable {
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
}

extension AppState {
  init() {
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
