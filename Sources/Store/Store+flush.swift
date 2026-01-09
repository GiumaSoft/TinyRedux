//


import Foundation


extension Store {

  /// Discards all pending actions in the dispatch buffer without interrupting the pipeline.
  /// Actions already being processed are not affected. Completions from discarded actions
  /// are invoked with the current state so that `dispatchWithResult` continuations always resume.
  nonisolated
  public func flush() {
    worker.dispatcher.flush()
    worker.onLog?(.store("flush"))
  }
}
