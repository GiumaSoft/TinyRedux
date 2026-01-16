// swift-tools-version: 6.0


import Foundation



/// ReduxOnlyState
///
///
@MainActor
/// A read-only projection of a mutable `ReduxState`.
public protocol ReadOnlyState: AnyObject,
                               Sendable {
  /// The state type wrapped by this projection.
  associatedtype State: ReduxState
  /// Initializes a read-only projection from the provided mutable state, enabling external
  /// observers to access values safely while hiding mutation capabilities and maintaining MainActor
  /// isolation semantics for UI and logging usage. Creates a read-only view for the given state
  /// instance.
  init(_ state: State)
}

/// ReduxState
///
///
@MainActor
/// A mutable state object observed by the UI. Conformers must provide a read-only projection via
/// `readOnly`.
public protocol ReduxState: AnyObject,
                            Observable,
                            Sendable {
  /// The read-only projection type for this state.
  associatedtype ReadOnly: ReadOnlyState where ReadOnly.State == Self
  /// A read-only view of the current state.
  var readOnly: ReadOnly { get }
}

