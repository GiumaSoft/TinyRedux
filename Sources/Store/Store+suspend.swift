//


import Foundation


extension Store {

  /// Flushes pending actions and suspends the store's dispatcher.
  /// New dispatches are silently dropped (`dispatch` returns `false`) until ``resume()`` is called.
  ///
  /// Active snapshot streams are eagerly finished: every consumer's `for await`
  /// loop ends promptly. ``resume()`` does **not** revive finished streams.
  ///
  /// - Warning: This API is intended for **testing purposes only**. Do not use it in production code.
  ///   Suspending a store in a live application can cause actions to be silently lost, leading to
  ///   inconsistent state and hard-to-diagnose bugs.
  nonisolated
  public func suspend() {
    guard worker.dispatcher.suspend() else { return }
    let worker = self.worker
    let onLog = worker.onLog

    Task { @MainActor in
      worker.finishAllStreams()
      onLog?(.store("suspend"))
    }
  }
}
