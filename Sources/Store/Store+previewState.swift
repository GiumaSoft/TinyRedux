// Store+previewState.swift
// TinyRedux

import Foundation

extension Store {

    /// Creates a store pre-loaded with the given state, suitable for SwiftUI previews.
    ///
    /// - Parameter state: The initial state for the preview.
    /// - Returns: A `Store` instance with no middleware, reducers, or resolvers.
    public static func previewState(_ state: State) -> Store<State, Action> {
        Store(
            initialState: state,
            middlewares: [],
            resolvers: [],
            reducers: []
        )
    }
}
