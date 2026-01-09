// Middleware.swift
// TinyRedux

import Foundation

/// Intercepts actions between dispatch and reduction, providing a composable extension point
/// for side effects.
///
/// A middleware sits in the action pipeline before any ``Reducer`` runs. It receives a
/// ``MiddlewareContext`` with the dispatched action and three capabilities:
/// `next` to forward the action down the chain, `dispatch` to enqueue new actions,
/// and `task` to launch controlled async operations with state access and error routing.
///
/// ## Rules
///
/// - `side-effects`: middleware is the **only** place for I/O, network calls, timers, and
///   any other work that is not a pure state assignment.
/// - `chain`: always call `next` to forward the action unless intentionally stopping the
///   pipeline (e.g. deduplication, throttling).
/// - `errors`: throw or use `task` to let the ``Resolver`` chain handle failures;
///   never swallow errors silently.
/// - `async`: use ``MiddlewareContext/task`` to launch async operations. The framework
///   wraps each task for automatic error routing and monitoring.
/// - `state`: access state only through ``MiddlewareContext/task`` (read-only). Use a
///   ``StatedMiddleware`` when cross-dispatch local state is needed.
public protocol Middleware: Identifiable, Sendable {

    /// The state type visible to this middleware.
    associatedtype State: ReduxState

    /// The action type this middleware intercepts.
    associatedtype Action: ReduxAction

    /// A stable identifier for logging and metrics.
    var id: String { get }

    /// Processes the action within the given context.
    ///
    /// - Parameter context: The current action, dispatch, task launcher, and pipeline callbacks.
    @MainActor func run(_ context: MiddlewareContext<State, Action>) throws
}
