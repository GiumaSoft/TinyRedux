//


import Foundation


/// AnyReducer
///
/// Type-erased wrapper around a ``Reducer``, stored as a closure.
public struct AnyReducer<S: ReduxState, A: ReduxAction>: Reducer {

  /// A stable identifier for logging and metrics.
  public let id: String

  /// The reduction closure that mutates state.
  public let reduce: ReduceHandler<S, A>

  /// Creates a type-erased reducer from a closure.
  ///
  /// - Parameters:
  ///   - id: Identifier for logging and metrics.
  ///   - reduce: Closure that mutates state for a given context.
  public init(
    id: String,
    _ reduce: @escaping ReduceHandler<S, A>
  ) {
    self.id = id
    self.reduce = reduce
  }

  /// Wraps an existing ``Reducer`` conformer via type erasure.
  ///
  /// - Parameter reducer: The reducer to wrap.
  public init<R: Reducer>(_ reducer: R)
  where R.S == S, R.A == A {
    self.id = reducer.id
    self.reduce = reducer.reduce
  }
}
