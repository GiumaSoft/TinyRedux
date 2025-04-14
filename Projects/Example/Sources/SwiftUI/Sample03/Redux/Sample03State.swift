//


import Foundation


typealias Sample03State = (
  header: String,
  message: String
)

extension AppState {
  var sample03: Sample03State {
    get {
      Sample03State(
        self.header,
        self.message
      )
    }
    set {
      (
        self.header,
        self.message
      ) = newValue
    }
  }
}

