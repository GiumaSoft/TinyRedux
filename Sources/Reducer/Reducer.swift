// swift-tools-version: 6.2


import Foundation

/// Reducer
///
/// Calculates new state values based on the current state and an incoming action.
///
/// Unlike classic Redux, where state is a value type returned as a new copy, here
/// ``ReduxState`` is an `Observable` reference type. The reducer mutates its properties
/// in place and SwiftUI picks up changes automatically through observation tracking.
/// A reducer is the only component in the pipeline allowed to write to state.
///
/// ## Rules
///
/// - Only derive changes from the `state` and `action` provided in the context.
/// - `side-effects`: never perform side effects; only state-assignment statements are allowed.
/// - `deterministic`: produce the same result for the same inputs.
/// - `O(1)`: only synchronous operations are allowed. Work require higher
///   complexity belongs in a ``Middleware``.
/// - `control-flow`: limit to `guard-else` or `if-else` with simple boolean conditions.
/// - `stateless`: do not use local persistent state outside of ``ReducerContext``.
public protocol Reducer: Identifiable,
                         Sendable {
  /// The state type this reducer mutates.
  associatedtype State: ReduxState

  /// The action type this reducer handles.
  associatedtype Action: ReduxAction
  
  /// A stable identifier for logging and metrics.
  var id: String { get }
  
  /// Applies the action to the state in the given context.
  ///
  /// - Parameter context: The current state and action pair.
  var reduce: @MainActor (ReducerContext<State, Action>) -> Void { get }
}
