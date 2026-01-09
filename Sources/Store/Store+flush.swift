//


import Foundation


extension Store {

  /// Discards all pending actions in the dispatch buffer without interrupting the pipeline.
  /// Actions already being processed are not affected. Stale events resume snapshot
  /// continuations with `.failure(.staleGeneration)`.
  nonisolated
  public func flush() {
    worker.dispatcher.flush()
    let onLog = worker.onLog

    Task { @MainActor in
      onLog?(.store("flush"))
    }
  }
}
