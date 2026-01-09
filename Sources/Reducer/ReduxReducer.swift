//


import Foundation


/// ReduxReducer
///
/// Computes state transitions from the current state and an incoming action.
/// ``ReduxState`` is an `Observable` reference type, so a reducer mutates it in
/// place and SwiftUI picks up the change via observation. It is the only
/// component allowed to write state, and must be deterministic, synchronous, and
/// free of side effects.
public protocol ReduxReducer: Identifiable,
                              Sendable
{
  /// The state type this reducer mutates.
  associatedtype S: ReduxState
  /// The action type this reducer handles.
  associatedtype A: ReduxAction

  /// A stable identifier for logging and metrics.
  var id: String { get }

  /// The reducing closure: mutates state and returns a ``ReduxReducerExit``.
  var reduce: ReduxReduceHandler<S, A> { get }
}
