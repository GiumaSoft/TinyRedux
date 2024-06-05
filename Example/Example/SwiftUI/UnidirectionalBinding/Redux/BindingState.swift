//


import Foundation


typealias BindingState = (
  header: String,
  message: String
)

extension AppState {
  var bindingState: BindingState {
    get {
      BindingState(
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

