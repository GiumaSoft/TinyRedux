//


import Foundation


/// A `String` tag identifying the action that originated a pipeline run (tracing,
/// logging, resolver context). Ported from `main`.
public typealias ReduxOrigin = String


/// An error that can cross isolation boundaries (effects throw off-main, the
/// resolver receives it on-main). `any Error` is NOT `Sendable`, so the exit
/// enums constrain it with `& Sendable`.
public typealias SendableError = any Error & Sendable


/// Subscription condition: evaluated against the read-only state on every change.
/// When it turns `true`, the matching ``SubscriptionHandler`` produces an action.
public typealias SubscriptionPredicate<S: ReduxState> =
  @MainActor @Sendable (S.ReadOnly) -> Bool


/// Subscription reaction: maps the read-only state to the action to dispatch when
/// the matching ``SubscriptionPredicate`` fires (State→Action).
public typealias SubscriptionHandler<S: ReduxState, A: ReduxAction> =
  @MainActor @Sendable (S.ReadOnly) -> A


/// Worker-provided hook stored in ``MiddlewareContext`` to register a subscription
/// (id, originating action, predicate, reaction). Backs `subscribe(id:when:then:)`.
public typealias RegisterSubscription<S: ReduxState, A: ReduxAction> =
  @MainActor @Sendable (String, A, @escaping SubscriptionPredicate<S>, @escaping SubscriptionHandler<S, A>) -> Void


/// Worker-provided hook stored in ``MiddlewareContext`` to remove a subscription by id.
public typealias UnregisterSubscription =
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
public typealias SnapshotRequest<S: ReduxState> =
  ( continuation: CheckedContinuation<ReduxEncodedSnapshot, Never>,
    capture: @MainActor @Sendable (S.ReadOnly, JSONEncoder) throws -> Data )


/// The once-only terminal callback threaded through the pipeline for a single-shot
/// snapshot. Built by the Worker from a ``SnapshotRequest`` and fired exactly once at
/// the action's terminal: `.success(state)` when it settles/absorbs, `.failure(error)`
/// when it fails. `nil` on the normal (non-snapshot) dispatch path.
public typealias SnapshotTerminal<S: ReduxState> =
  @MainActor (Result<S.ReadOnly, SendableError>) -> Void
