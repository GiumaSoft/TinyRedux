//


import Foundation


typealias Sample01State = (
  Array<Date>
)

extension AppState {
  var sample01State: Sample01State {
    get {
      Sample01State(
        self.dates
      )
    }
    set {
      (
        self.dates
      ) = newValue
    }
  }
}
