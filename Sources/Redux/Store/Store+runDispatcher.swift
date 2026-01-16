// swift-tools-version: 6.0


import Foundation


extension Store {
  /// Starts the dispatcher loop if not already running, drains the action buffer in order, logs
  /// lifecycle events, and resets the running flag when processing completes for subsequent
  /// dispatches and safety. Runs the dispatcher loop to process buffered actions.
  func runDispatcher() {
    if isDispatcherRunning { return }
    
    defer {
      onLog?(.store("dispatcher terminated."))
      isDispatcherRunning = false
    }
    
    isDispatcherRunning = true
    onLog?(.store("run dispatcher."))
    while let action = actionBuffer.popFirst()  {
      onLog?(.store("actions in queue [\(remainingActions)]."))
      defer { decreaseCount(for: action) }
      dispatchProcess(action)
    }
  }
}
