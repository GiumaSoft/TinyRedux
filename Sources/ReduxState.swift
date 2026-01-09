//


import Foundation


/// ReduxState
///
/// The mutable application state observed by the UI. Conformers are `Observable`
/// reference types (`AnyObject`) whose properties reducers mutate in place;
/// `Sendable` lets the state cross the store's isolation boundaries. Each
/// conformer exposes a ``ReadOnly`` projection handed to read-only consumers, so
/// only reducers can write. Mark conformers `@MainActor` to keep mutable
/// observable state isolated to the main actor.
public protocol ReduxState: AnyObject,
                            Observable,
                            Sendable
{
  /// The read-only projection type for this state.
  associatedtype ReadOnly: ReduxReadOnlyState where ReadOnly.State == Self

  /// A read-only view of the current state.
  @MainActor
  var readOnly: ReadOnly { get }
}


/// ReduxReadOnlyState
///
/// Read-only projection of a ``ReduxState``: exposes the observable properties
/// without setters, so consumers can read and observe but not mutate. Typically
/// forwards each property to the backing state instance passed at `init`.
public protocol ReduxReadOnlyState: AnyObject,
                                    Observable,
                                    Sendable
{
  /// The state this projection mirrors.
  associatedtype State: ReduxState

  /// Creates a projection backed by the given state.
  init(_ state: State)
}
