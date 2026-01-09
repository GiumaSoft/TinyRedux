//


import Foundation


extension Store {

  /// Resumes a suspended store, allowing new dispatches to be enqueued again.
  ///
  /// - Warning: This API is intended for **testing purposes only**. Do not use it in production code.
  nonisolated
  public func resume() {
    guard worker.dispatcher.resume() else { return }
    let onLog = worker.onLog

    Task { @MainActor in
      onLog?(.store("resume"))
    }
  }
}
