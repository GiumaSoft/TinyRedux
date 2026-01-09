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
/// - ``dispatch(_:snapshot:)`` — `async`, returns `Result<Data, Error>` with encoded state snapshot.
///
/// All dispatch entry points are `nonisolated` and thread-safe.
@Observable
@dynamicMemberLookup
public final class Store<S: ReduxState, A: ReduxAction>: Sendable {
  
  // MARK: - Properties
  
  @ObservationIgnored
  @MainActor
  var _state: S

  @ObservationIgnored
  let worker: Worker
  
  // MARK: - Init
  
  public init(
    initialState state: S,
    middlewares: [AnyMiddleware<S, A>],
    resolvers: [AnyResolver<S, A>],
    reducers: [AnyReducer<S, A>],
    options: StoreOptions = .init(),
    onLog: LogHandler<S, A>? = nil
  ) {
    self._state = state
    self.worker = Worker(
      initialState: state,
      middlewares: middlewares,
      resolvers: resolvers,
      reducers: reducers,
      options: options,
      onLog: onLog
    )
  }
  
  deinit {
    worker.dispatcher.finish()
  }
  
  // MARK: - Public API
  
  @MainActor
  public var state: S.ReadOnly {
    _state.readOnly
  }
  
  /// Accesses read-only state via dynamic member lookup.
  @MainActor
  public subscript<Value>(dynamicMember keyPath: KeyPath<S.ReadOnly, Value>) -> Value {
    state[keyPath: keyPath]
  }
}
