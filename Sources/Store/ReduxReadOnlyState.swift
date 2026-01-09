// ReduxReadOnlyState.swift
// TinyRedux

import Foundation

/// ReduxReadOnlyState
///
/// Read-only projection of a ``ReduxState``, hiding mutation from external observers.
@MainActor
public protocol ReduxReadOnlyState: AnyObject,
                                    Observable,
                                    Sendable {

    /// The mutable state type wrapped by this projection.
    associatedtype State: ReduxState

    /// Creates a read-only view for the given state.
    ///
    /// - Parameter state: The mutable state to project.
    @MainActor init(_ state: State)
}
