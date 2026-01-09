//


import Foundation


// MARK: - Common


/// Type-erased error used across pipeline boundaries.
public typealias SendableError = any Error

/// Identifier of the middleware that originated an error.
public typealias ReduxOrigin = String

/// Completion callback invoked with read-only state after pipeline processing.
public typealias ActionHandler<S: ReduxState> = @Sendable (S.ReadOnly) -> Void

/// Enqueues one or more actions for future dispatch (nonisolated, thread-safe).
public typealias ReduxDispatch<A: ReduxAction> = @Sendable (UInt, A...) -> Void


// MARK: - Store


/// Log handler for timing and diagnostics.
public typealias LogHandler<S: ReduxState, A: ReduxAction> = @Sendable (Store<S, A>.Log) -> Void

/// Top-level dispatch process built once at init by `buildDispatchProcess()`.
internal typealias ProcessHandler<S: ReduxState, A: ReduxAction> = @MainActor (S.ReadOnly, A, ActionHandler<S>?) -> Void

/// Dispatcher event tuple: action paired with its optional completion handler.
internal typealias ActionEvent<S: ReduxState, A: ReduxAction> = (action: A, completion: ActionHandler<S>?)


// MARK: - Middleware


/// Middleware `run()` closure signature.
public typealias MiddlewareHandler<S: ReduxState, A: ReduxAction> = @MainActor (MiddlewareContext<S, A>) throws -> MiddlewareExit<S, A>

/// Destructured middleware context tuple: (state, dispatch, action).
public typealias MiddlewareArgs<S: ReduxState, A: ReduxAction> = (S.ReadOnly, ReduxDispatch<A>, A)

/// Deferred resume callback invoked to continue the pipeline.
public typealias ResumeHandler<A: ReduxAction> = @Sendable (MiddlewareResumeExit<A>) -> Void

/// Fire-and-forget async task body with read-only state access.
public typealias TaskHandler<S: ReduxState> = @Sendable (S.ReadOnly) async throws -> Void

/// Deferred async handler with read-only state access; returns a resume exit to continue the pipeline.
public typealias DeferredTaskHandler<S: ReduxState, A: ReduxAction> = @Sendable (S.ReadOnly) async throws -> MiddlewareResumeExit<A>

/// Middleware chain step in the pipeline fold: processes action then calls completion.
public typealias MiddlewareChain<S: ReduxState, A: ReduxAction> = @MainActor (S.ReadOnly, A, ActionHandler<S>?) -> Void

/// Forwards an action to the next step in the middleware fold chain.
internal typealias MiddlewareNext<A: ReduxAction> = @MainActor (A) -> Void

/// Launches a fire-and-forget task with error routing to the resolver chain.
internal typealias RunTask<S: ReduxState, A: ReduxAction> = @MainActor (@escaping TaskHandler<S>, A, ReduxOrigin) -> Void

/// Launches a deferred task, wiring resume and next into the pipeline.
internal typealias RunDeferredTask<S: ReduxState, A: ReduxAction> = @MainActor (@escaping DeferredTaskHandler<S, A>, @escaping MiddlewareNext<A>, A, ReduxOrigin, ActionHandler<S>?) -> Void


// MARK: - Reducer


/// Reducer `reduce` closure signature.
public typealias ReduceHandler<S: ReduxState, A: ReduxAction> = @MainActor (ReducerContext<S, A>) -> ReducerExit

/// Reducer step in the pipeline fold: applies action then calls completion.
internal typealias ReduceChain<S: ReduxState, A: ReduxAction> = @MainActor (A, ActionHandler<S>?) -> Void


// MARK: - Resolver


/// Resolver `run()` closure signature.
public typealias ResolveHandler<S: ReduxState, A: ReduxAction> = @MainActor (ResolverContext<S, A>) -> ResolverExit<A>

/// Destructured resolver context tuple: (state, dispatch, error, origin, action).
public typealias ResolverArgs<S: ReduxState, A: ReduxAction> = (S.ReadOnly, ReduxDispatch<A>, SendableError, ReduxOrigin, A)

/// Resolver step in the pipeline fold: routes error then calls completion.
internal typealias ResolveChain<S: ReduxState, A: ReduxAction> = @MainActor (SendableError, A, ReduxOrigin, ActionHandler<S>?) -> Void


// MARK: - Subscription


/// Predicate evaluated post-reducer to determine if a subscription must fire.
/// Reads only the read-only state; does not depend on the current action.
public typealias SubscriptionPredicate<S: ReduxState> = @MainActor @Sendable (S.ReadOnly) -> Bool

/// Action builder invoked at subscription match time to compose the dispatched action from the fresh post-reducer state.
public typealias SubscriptionHandler<S: ReduxState, A: ReduxAction> = @MainActor @Sendable (S.ReadOnly) -> A

/// Subscription chain step in the pipeline fold: evaluates entries post-reducer and enqueues matched actions.
internal typealias SubscriptionChain = @MainActor () -> Void
