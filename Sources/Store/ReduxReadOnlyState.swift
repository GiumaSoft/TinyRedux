// swift-tools-version: 6.2


import SwiftUI


/// ReduxReadOnlyState
/// 
/// Read-only projection of a ``ReduxState``, hiding mutation from external observers.
public protocol ReduxReadOnlyState: AnyObject,
                                    Sendable {
  /// The mutable state type wrapped by this projection.
  associatedtype State: ReduxState

  /// Creates a read-only view for the given state.
  ///
  /// - Parameter state: The mutable state to project.
  @MainActor init(_ state: State)
}
