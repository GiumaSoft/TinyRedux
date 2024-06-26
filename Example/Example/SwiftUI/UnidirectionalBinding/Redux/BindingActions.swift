//


import Foundation


enum BindingActions {
  case setHeader(String)
  case setMessage(String)
}

extension BindingActions: Equatable {
  static func == (lhs: BindingActions, rhs: BindingActions) -> Bool {
    switch (lhs, rhs) {
    case (.setHeader, .setHeader),
         (.setMessage, .setMessage):
          true
    default:
          false
    }
  }
}


extension AppActions {
  var binding: BindingActions? {
    get { if case .binding(let value) = self { value } else { nil } }
    set { if case .binding = self, let newValue { self = .binding(newValue) } else { return } }
  }
}

