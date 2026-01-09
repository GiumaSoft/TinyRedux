//


import Foundation
import Observation
import SwiftUI


/// Store
///
/// Central hub of the Supervised Redux Model. Holds the mutable state, the
/// middleware/reducer/resolver pipeline, and exposes a read-only state projection
/// for SwiftUI observation via `@dynamicMemberLookup`.
///
/// Actions are dispatched through `nonisolated` entry points and serialized by an
/// internal ``Worker`` that processes them on `@MainActor` via an `AsyncStream`.
/// The pipeline executes synchronously: middlewares → reducers → (on error) resolvers.
///
/// ## Lifecycle
///
/// - `init`: creates the ``Worker``, builds the dispatch pipeline, and starts the
///   event loop. No separate `start()` call is needed.
/// - `deinit`: calls `dispatcher.finish()`, which terminates the stream and lets
///   the worker task complete.
///
/// ## Dispatch API
///
/// - ``dispatch(maxDispatchable:_:)`` — fire-and-forget (variadic).
/// - ``dispatch(maxDispatchable:_:completion:)`` — callback with post-mutation state.
/// - ``dispatchWithResult(maxDispatchable:_:)`` — `async`, returns post-mutation state.
///
/// `dispatch` entry points are `nonisolated` and thread-safe.
/// `dispatchWithResult` is `@MainActor` (`async`, uses continuation).
@MainActor @Observable
@dynamicMemberLookup
public final class Store<S: ReduxState, A: ReduxAction> {
  
  // MARK: - Properties
  
  @ObservationIgnored
  var _state: S

  @ObservationIgnored
  nonisolated
  let worker: Worker
  
  // MARK: - Init
  
  public init(
    initialState state: S,
    middlewares: [AnyMiddleware<S, A>],
    resolvers: [AnyResolver<S, A>],
    reducers: [AnyReducer<S, A>],
    onLog: LogHandler<S, A>? = nil
  ) {
    self._state = state
    self.worker = Worker(
      initialState: state,
      middlewares: middlewares,
      resolvers: resolvers,
      reducers: reducers,
      onLog: onLog
    )
  }
  
  deinit {
    worker.dispatcher.finish()
  }
  
  // MARK: - Public API
  
  public var state: S.ReadOnly {
    _state.readOnly
  }
  
  /// Accesses read-only state via dynamic member lookup.
  public subscript<Value>(dynamicMember keyPath: KeyPath<S.ReadOnly, Value>) -> Value {
    state[keyPath: keyPath]
  }
}
