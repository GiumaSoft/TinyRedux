//


import Foundation


extension Store {

  /// Discards all pending actions in the dispatch buffer without interrupting the pipeline.
  /// Actions already being processed are not affected. Stale events resume snapshot
  /// continuations with `.failure(.staleGeneration)`.
  ///
  /// Active snapshot streams are eagerly finished: every consumer's `for await`
  /// loop ends promptly. A reducing action processed before the finish lands may
  /// emit one final valid frame.
  nonisolated
  public func flush() {
    worker.dispatcher.flush()
    let worker = self.worker
    let onLog = worker.onLog

    Task { @MainActor in
      worker.finishAllStreams()
      onLog?(.store("flush"))
    }
  }
}
