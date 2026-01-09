// AnyResolver.swift
// TinyRedux

import Foundation

/// AnyResolver
///
/// Type-erased wrapper around a ``Resolver``, stored as a closure.
@frozen
public struct AnyResolver<S: ReduxState, A: ReduxAction>: Resolver, Identifiable {

    /// A stable identifier for logging and metrics.
    public let id: String

    private let handler: @MainActor (ResolverContext<S, A>) -> Void

    /// Creates a type-erased resolver from a closure.
    ///
    /// - Parameters:
    ///   - id: Identifier for logging and metrics.
    ///   - handler: The resolver logic.
    public init(
        id: String,
        handler: @escaping @MainActor (ResolverContext<S, A>) -> Void
    ) {
        self.id = id
        self.handler = handler
    }

    /// Wraps an existing ``Resolver`` conformer via type erasure.
    ///
    /// - Parameter resolver: The resolver to wrap.
    public init<R: Resolver>(_ resolver: R)
    where R.S == S, R.A == A {
        self.id = resolver.id
        self.handler = { context in
            resolver.run(context)
        }
    }

    /// Executes the stored handler with the given context.
    @MainActor
    public func run(_ context: ResolverContext<S, A>) {
        handler(context)
    }
}
