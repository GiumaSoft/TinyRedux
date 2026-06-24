//


import Foundation


/// A `String` tag identifying the action that originated a pipeline run (tracing,
/// logging, resolver context). Ported from `main`.
public typealias ReduxOrigin = String


/// An error that can cross isolation boundaries (effects throw off-main, the
/// resolver receives it on-main). `any Error` is NOT `Sendable`, so the exit
/// enums constrain it with `& Sendable`.
public typealias ReduxSendableError = any Error & Sendable


// MARK: - Context `args` (destructurable member tuples)

/// Destructured members of a ``ReduxReducerContext``: `(state, action)`.
public typealias ReduxReducerArgs<S: ReduxState, A: ReduxAction> =
  ( state: S,
    action: A )

/// Destructured members of a ``ReduxMiddlewareContext``:
/// `(state, dispatch, action, subscribe, unsubscribe)`.
public typealias ReduxMiddlewareArgs<S: ReduxState, A: ReduxAction> =
  ( state: S,
    dispatch: @Sendable (A) -> Void,
    action: A,
    subscribe: ReduxMiddlewareSubscribe<S, A>,
    unsubscribe: ReduxUnregisterSubscription )

/// Destructured members of a ``ReduxResolverContext``:
/// `(state, dispatch, error, origin, action)`.
public typealias ReduxResolverArgs<S: ReduxState, A: ReduxAction> =
  ( state: S,
    dispatch: @Sendable (A) -> Void,
    error: ReduxSendableError,
    origin: ReduxOrigin,
    action: A )


/// ReduxSubscription condition: evaluated against the read-only state on every change.
/// When it turns `true`, the matching ``ReduxSubscriptionHandler`` produces an action.
public typealias ReduxSubscriptionPredicate<S: ReduxState> =
  @MainActor @Sendable (S.ReadOnly) -> Bool


/// ReduxSubscription reaction: maps the read-only state to the action to dispatch when
/// the matching ``ReduxSubscriptionPredicate`` fires (State→Action).
public typealias ReduxSubscriptionHandler<S: ReduxState, A: ReduxAction> =
  @MainActor @Sendable (S.ReadOnly) -> A


/// Worker-provided hook stored in ``ReduxMiddlewareContext`` to register a subscription
/// (id, originating action, predicate, reaction). Backs `subscribe(id:when:then:)`.
public typealias ReduxRegisterSubscription<S: ReduxState, A: ReduxAction> =
  @MainActor @Sendable (String, A, @escaping ReduxSubscriptionPredicate<S>, @escaping ReduxSubscriptionHandler<S, A>) -> Void


/// Worker-provided hook stored in ``ReduxMiddlewareContext`` to remove a subscription by id.
public typealias ReduxUnregisterSubscription =
  @MainActor @Sendable (String) -> Void


// MARK: - Snapshot

/// The transportable result of a snapshot capture: JSON `Data` on success, or the
/// pipeline / rejection / encoding error on failure. Returned by both snapshot
/// dispatch overloads (single value, or each frame of the stream).
public typealias ReduxEncodedSnapshot = Result<Data, Error>


/// A pending single-shot snapshot request, riding ``TaggedActionEvent`` through the
/// dispatcher stream to the `@MainActor` loop. `continuation` resumes the caller of
/// `dispatch(_:snapshot:)`; `capture` builds the encoded projection from the settled
/// read-only state. A tuple typealias (not a struct) so it lives here with the other
/// aliases; `Sendable` because both members are.
public typealias ReduxSnapshotRequest<S: ReduxState> =
  ( continuation: CheckedContinuation<ReduxEncodedSnapshot, Never>,
    capture: @MainActor @Sendable (S.ReadOnly, JSONEncoder) throws -> Data )


/// The once-only terminal callback threaded through the pipeline for a single-shot
/// snapshot. Built by the Worker from a ``ReduxSnapshotRequest`` and fired exactly once at
/// the action's terminal: `.success(state)` when it settles/absorbs, `.failure(error)`
/// when it fails. `nil` on the normal (non-snapshot) dispatch path.
public typealias ReduxSnapshotTerminal<S: ReduxState> =
  @MainActor (Result<S.ReadOnly, ReduxSendableError>) -> Void
