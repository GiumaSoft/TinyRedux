// Resolver.swift
// TinyRedux

import Foundation

/// Resolver
///
/// Handles errors thrown during middleware execution, with the option to dispatch recovery actions.
public protocol Resolver: Identifiable, Sendable {

    /// The state type visible to this resolver.
    associatedtype S: ReduxState

    /// The action type this resolver handles.
    associatedtype A: ReduxAction

    /// A stable identifier for logging and metrics.
    var id: String { get }

    /// Processes the error within the given context.
    ///
    /// - Parameter context: The error, originating action, read-only state, and pipeline callbacks.
    @MainActor func run(_ context: ResolverContext<S, A>)
}
