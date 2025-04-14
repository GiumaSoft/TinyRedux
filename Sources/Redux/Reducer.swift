

import Foundation


@frozen
public struct ReducerContext<A> where A : ReduxAction {
  public let action: A
  public let handled: () -> Void
  
  public init(action: A, handled: @escaping () -> Void) {
    self.action = action
    self.handled = handled
  }
}


@frozen
public struct Reducer<S, A> where S : ReduxState, A : ReduxAction {
  ///
  public let id: String
  ///
  @usableFromInline
  let reduce: @MainActor (inout S, ReducerContext<A>) throws -> Void

  public init(id: String, handler: @escaping @MainActor (inout S, ReducerContext<A>) throws -> Void) {
    self.id = id
    self.reduce = handler
  }
}
