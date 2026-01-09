// AnyResolver.swift
// TinyRedux

import Foundation

/// AnyResolver
///
/// Type-erased wrapper around a ``Resolver``, stored as a closure.
@frozen
public struct AnyResolver<State: ReduxState, Action: ReduxAction>: Resolver, Identifiable {

    /// A stable identifier for logging and metrics.
    public let id: String

    private let handler: @MainActor (ResolverContext<State, Action>) -> Void

    /// Creates a type-erased resolver from a closure.
    ///
    /// - Parameters:
    ///   - id: Identifier for logging and metrics.
    ///   - handler: The resolver logic.
    public init(
        id: String,
        handler: @escaping @MainActor (ResolverContext<State, Action>) -> Void
    ) {
        self.id = id
        self.handler = handler
    }

    /// Wraps an existing ``Resolver`` conformer via type erasure.
    ///
    /// - Parameter resolver: The resolver to wrap.
    public init<R: Resolver>(_ resolver: R)
    where R.State == State, R.Action == Action {
        self.id = resolver.id
        self.handler = { context in
            resolver.run(context)
        }
    }

    /// Executes the stored handler with the given context.
    public func run(_ context: ResolverContext<State, Action>) {
        handler(context)
    }
}
