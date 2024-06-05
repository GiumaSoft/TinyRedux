//


import Foundation


enum BindingActions {
  case setHeader(String)
  case setMessage(String)
}

extension AppActions {
  var binding: BindingActions? {
    get { if case .binding(let value) = self { value } else { nil } }
    set { if case .binding = self, let newValue { self = .binding(newValue) } else { return } }
  }
}
