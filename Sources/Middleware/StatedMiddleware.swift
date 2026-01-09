// StatedMiddleware.swift
// TinyRedux

import Foundation

/// StatedMiddleware
///
/// A ``Middleware`` variant that captures a coordinator for stateful side effects across dispatches.
@frozen
public struct StatedMiddleware<S: ReduxState, A: ReduxAction>: Middleware, Identifiable {

    /// A stable identifier for logging and metrics.
    public let id: String

    private let handler: @MainActor (MiddlewareContext<S, A>) throws -> Void

    /// Creates a stateful middleware bound to a coordinator.
    ///
    /// - Parameters:
    ///   - id: Identifier for logging and metrics.
    ///   - coordinator: Object that holds local state across dispatches.
    ///   - handler: Closure receiving the coordinator and middleware context.
    public init<C: AnyObject & Sendable>(
        id: String,
        coordinator: C,
        handler: @escaping @MainActor (C, MiddlewareContext<S, A>) throws -> Void
    ) {
        self.id = id
        self.handler = { context in
            try handler(coordinator, context)
        }
    }

    /// Executes the stored handler with the given context.
    @MainActor
    public func run(_ context: MiddlewareContext<S, A>) throws {
        try handler(context)
    }
}
