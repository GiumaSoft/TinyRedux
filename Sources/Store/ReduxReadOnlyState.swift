//


import Foundation


/// ReduxReadOnlyState
///
/// Read-only projection of a ``ReduxState``, exposing observable properties
/// without setters. ``Middleware``s and ``Resolver``s receive this type to
/// prevent accidental state mutation outside the reducer chain.
///
/// The projection is created once via ``init(_:)`` and mirrors the mutable
/// state's observable properties. SwiftUI views can observe it directly.
///
/// ## Rules
///
/// - `@MainActor`: mirrors the isolation of the underlying ``ReduxState``.
/// - `Observable`: supports SwiftUI observation.
/// - `Sendable`: required for cross-isolation access.
/// - `init(_:)`: must initialize from the associated ``State`` type.
@MainActor
public protocol ReduxReadOnlyState: AnyObject,
                                    Observable,
                                    Sendable {

    /// The mutable state type wrapped by this projection.
    associatedtype State: ReduxState

    /// Creates a read-only view for the given state.
    ///
    /// - Parameter state: The mutable state to project.
    init(_ state: State)
}
