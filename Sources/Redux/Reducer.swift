

import Foundation

public typealias ReducerContext<S, A> = (
  state: S,
  action: A,
  complete: () -> Void
) where S : ReduxState, A : ReduxAction

@frozen
/// A reducer that mutates state in response to actions.
public struct Reducer<S: ReduxState, A: ReduxAction> {
  /// A stable identifier for logging and metrics.
  public let id: String
  
  internal let reduce: @MainActor @Sendable (ReducerContext<S, A>) -> Void
  
  /// Creates a reducer with the given identifier and body.
  /// - Parameters:
  ///   - id: Identifier for logging and metrics.
  ///   - reduce: The reducer body that mutates state.
  public init(id: String, _ reduce: @escaping @MainActor @Sendable (ReducerContext<S, A>) -> Void) {
    self.id = id
    self.reduce = reduce
  }
}
