//


import SwiftUI


extension Sample.SwiftUI.Sample04View {
  var effectAlertPresentedBind: Binding<Bool> {
    store.bind(\.effectAlertPresented, maxDispatchable: 1) { .setEffectAlertPresented($0) }
  }
  
  var effectAlertMessage: String {
    "\(store.effectAlertMessage, default: "Unknown")"
  }
  
  var effectIsRunning: Bool {
    store.effectIsRunning
  }
  
  var effectMessage: String {
    store.effectMessage
  }
  
  var effectIsRunningStatus: String {
    store.effectIsRunning ? "Running..." : "Run Effect"
  }
  
  var buttonOpacity: CGFloat {
    store.effectIsRunning ? 0.6 : 1.0
  }
  
  var buttonForeground: Color {
    store.effectIsRunning ? .white : .blue
  }
}

extension Sample.SwiftUI.Sample04View {
  func dispatch(maxDispatchable limit: UInt = 0, _ action: AppActions) -> Void {
    store.dispatch(maxDispatchable: limit, action)
  }
}
