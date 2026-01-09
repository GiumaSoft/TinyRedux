//


import Foundation


/// Configuration options for ``Store``.
///
/// Holds runtime parameters that influence dispatcher behavior. The default
/// initializer produces values tuned for typical app workloads (bootstrap
/// sequences, mid-frequency UI events). Adjust only when the workload calls
/// for it.
public struct StoreOptions: Sendable {

  /// Maximum number of actions accepted by the dispatcher and not yet completed.
  ///
  /// Counts both queued actions awaiting the worker and the action currently
  /// being processed by the reducer / synchronous middleware. The slot is
  /// freed only after that processing returns. New enqueues exceeding this
  /// limit are rejected with `bufferLimitReached`.
  ///
  /// The capacity does **not** bound `.task` / `.deferred` async work already
  /// started by middlewares — those run outside the dispatcher and may execute
  /// concurrently in unbounded number. Only re-entrant `dispatch` calls from
  /// such tasks are subject to this limit.
  ///
  /// The default of `256` matches the historical buffer size used by the
  /// dispatcher's transport stream. Invalid values assert in debug builds and
  /// clamp to `1`, avoiding production crashes and avoiding a dispatcher that
  /// rejects every action because of an accidental zero or negative capacity.
  public let dispatcherCapacity: Int

  public init(dispatcherCapacity: Int = 256) {
    assert(dispatcherCapacity > 0, "dispatcherCapacity must be greater than 0")
    self.dispatcherCapacity = max(1, dispatcherCapacity)
  }
}
