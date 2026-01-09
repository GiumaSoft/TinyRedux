// AnyReducer.swift
// TinyRedux

import Foundation

/// AnyReducer
///
/// Type-erased wrapper around a ``Reducer``, stored as a closure.
@frozen
public struct AnyReducer<S: ReduxState, A: ReduxAction>: Reducer, Identifiable {

    /// A stable identifier for logging and metrics.
    public let id: String

    /// The reduction closure that mutates state.
    public let reduce: @MainActor (ReducerContext<S, A>) -> Void

    /// Creates a type-erased reducer.
    ///
    /// - Parameters:
    ///   - id: Identifier for logging and metrics.
    ///   - reduce: Closure that mutates state for a given context.
    public init(
        id: String,
        _ reduce: @escaping @MainActor (ReducerContext<S, A>) -> Void
    ) {
        self.id = id
        self.reduce = reduce
    }
}
