//


import Foundation


/// Reason a dispatch was rejected by the dispatcher.
///
/// Returned inside `Result<Data, Error>` from `dispatch(_:snapshot:)` when the
/// action cannot be enqueued. Also used internally by fire-and-forget dispatch
/// to decide whether to emit a discard log.
public enum EnqueueFailure: Error, Equatable, Sendable {

  /// `pendingCount` already at `dispatcherCapacity` when the enqueue was attempted.
  case bufferLimitReached

  /// `counts[id]` already at the per-action `limit` requested by the caller.
  case maxDispatchableReached

  /// The dispatcher is suspended; new actions are not accepted until `resume()`.
  case suspended

  /// The expected generation no longer matches the current one — used to drop
  /// race-condition enqueues across `flush()` / `suspend()`. Treated as silent.
  case staleGeneration

  /// The dispatcher stream has been terminated and can no longer accept events.
  case terminated
}


extension EnqueueFailure {

  /// Human-readable reason embedded in the store discard log.
  var reason: String {
    switch self {
    ///
    case .bufferLimitReached:

      return "buffer limit reached"
    ///
    case .maxDispatchableReached:

      return "max dispatchable reached"
    ///
    case .suspended:

      return "dispatcher suspended"
    ///
    case .staleGeneration:

      return "stale generation"
    ///
    case .terminated:

      return "dispatcher terminated"
    }
  }
}
