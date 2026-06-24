

import Observation
import SwiftUI


/// ReduxStore
///
/// Central hub of the store: holds the mutable ``ReduxState`` (`_state`) and the
/// ``Worker`` that serializes and reduces actions. Actions are published through the
/// `nonisolated` ``dispatch(_:)`` and processed on the main actor by the worker;
/// read-only state is exposed via `state` (a `S.ReadOnly`) and `@dynamicMemberLookup`.
/// Conforms to ``ReduxModule`` so it is itself a standalone module over `S`/`A`.
@Observable
@dynamicMemberLookup
public final class ReduxStore<S, A> : ReduxModule, Sendable
where S: ReduxState, A: ReduxAction
{
  @MainActor
  let _state: S

  let worker: Worker

  public init( initialState state: S,
               reducers: [AnyReduxReducer<S, A>],
               middlewares: [AnyReduxMiddleware<S, A>] = [],
               resolvers: [AnyReduxResolver<S, A>] = [],
               options: ReduxStoreOptions = .init(),
               onLog: ReduxLogHandler<S, A>? = nil )
  {
    self._state = state
    self.worker = Worker(
      initialState: state,
      reducers: reducers,
      middlewares: middlewares,
      resolvers: resolvers,
      options: options,
      onLog: onLog
    )
  }

  /// Terminates the dispatcher stream (ending the worker loop) and eagerly finishes every
  /// active snapshot stream so consumers' `for await` loops end. The stream teardown hops to
  /// the main actor: `Worker.finishAllStreams()` touches the `@MainActor` `Streams` registry,
  /// which a nonisolated `deinit` cannot reach directly. The captured `worker` keeps the
  /// instance alive until the hop completes.
  deinit
  {
    worker.dispatcher.finish()
    let worker = self.worker
    Task { @MainActor in worker.finishAllStreams() }
  }

  /// Read-only projection of the current state.
  @MainActor
  public var state: S.ReadOnly { _state.readOnly }

  /// Reads a value from the read-only state via dynamic member lookup.
  @MainActor
  public subscript<Value>(dynamicMember keyPath: KeyPath<S.ReadOnly, Value>) -> Value
  {
    _state.readOnly[keyPath: keyPath]
  }
}
