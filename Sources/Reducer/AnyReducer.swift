// swift-tools-version: 6.2


import Foundation

/// Reducer
/// 
/// Type-erased wrapper around a ``Reducer``, stored as a closure.
@frozen
public struct AnyReducer<State, Action>: Reducer where State : ReduxState, Action : ReduxAction {
  /// A stable identifier for logging and metrics.
  public let id: String

  /// The reduction closure that mutates state.
  public let reduce: @MainActor (ReducerContext<State, Action>) -> Void

  /// Creates a type-erased reducer.
  ///
  /// - Parameters:
  ///   - id: Identifier for logging and metrics.
  ///   - reduce: Closure that mutates state for a given context.
  public init(id: String, _ reduce: @MainActor @escaping (ReducerContext<State, Action>) -> Void) {
    self.id = id
    self.reduce = reduce
  }
}
