//


import Foundation


struct AppState {
  var header: String
  var message: String
  var counter: Int
  var counterMessage: String
  var timeCount: Int
  var timerIsRunning: Bool
}

extension AppState {
  init() {
    self.init(
      header: "Lorem ipsum",
      message: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nullam eu fringilla libero, sed euismod ipsum.",
      counter: 0,
      counterMessage: "",
      timeCount: 0,
      timerIsRunning: false
    )
  }
}
