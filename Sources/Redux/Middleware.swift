//


/// Middleware
///
///

/// Contesto passato al middleware per l'esecuzione
@frozen public struct MiddlewareContext<S, A> where S : ReduxState, A : ReduxAction {
  /// Stato corrente (read-only)
  public let state: S.ReadOnly
  /// Funzione per dispatch di nuove azioni
  public let dispatch: @MainActor (A) -> Void
  /// Funzione per continuare la catena di middleware
  public let next: @MainActor (A) throws -> Void
  /// Azione corrente
  public let action: A
  
  public init(
    state: S.ReadOnly,
    dispatch: @escaping @MainActor (A) -> Void,
    next: @escaping @MainActor (A) throws  -> Void,
    action: A
  ) {
    self.state = state
    self.dispatch = dispatch
    self.next = next
    self.action = action
  }
  
  public var args: (S.ReadOnly, @MainActor (A) -> Void, @Sendable (A) async -> Void, @MainActor (A) throws -> Void, @Sendable (A) async throws -> Void, A) {
    (
      self.state,
      self.dispatch,
      { action in
        await MainActor.run { self.dispatch(action) }
      },
      self.next,
      { action in
        try await MainActor.run { try self.next(action) }
      },
      self.action
    )
  }
}


public protocol AnyMiddleware {
  associatedtype S: ReduxState
  associatedtype A: ReduxAction
  
  @MainActor
  func run(_ context: MiddlewareContext<S, A>) throws
}



/// Middleware concreto con closure
@frozen public struct Middleware<S, A>: AnyMiddleware where S : ReduxState, A : ReduxAction {
  private let handler: @MainActor (MiddlewareContext<S, A>) throws -> Void
  
  public init(_ handler: @escaping @MainActor (MiddlewareContext<S, A>) throws -> Void) {
    self.handler = handler
  }
  
  public init<M>(_ middleware: M) where M : AnyMiddleware, M.S == S, M.A == A {
    self.handler = { context in try middleware.run(context) }
  }
  
  public init<M, LS, LA>(
    _ middleware: M,
    toState state: KeyPath<S.ReadOnly, LS.ReadOnly> & Sendable,
    toAction action: KeyPath<A, LA?> & Sendable,
    toGlobalAction tGA: @escaping @Sendable (LA) -> A
  ) where M : AnyMiddleware, M.S == LS, M.A == LA {
    self.init { context in
      guard let localAction = context.action[keyPath: action] else {
        try context.next(context.action)
        return
      }
      
      try middleware.run(
        MiddlewareContext(
          state: context.state[keyPath: state],
          dispatch: { localAction in context.dispatch(tGA(localAction)) },
          next: { localAction in try context.next(tGA(localAction)) },
          action: localAction
        )
      )
    }
  }
  
  @MainActor
  public func run(_ context: MiddlewareContext<S, A>) throws {
    try handler(context)
  }
}


/// Middleware con stato interno
@frozen
public struct StatedMiddleware<T: Sendable, S: ReduxState, A: ReduxAction>: AnyMiddleware {
  private let handler: @MainActor (T, MiddlewareContext<S, A>) throws -> Void
  private let coordinator: T
  
  public init(
    coordinator: T,
    handler: @escaping @MainActor (T, MiddlewareContext<S, A>) throws -> Void
  ) {
    self.coordinator = coordinator
    self.handler = handler
  }
  
  @MainActor
  public func run(_ context: MiddlewareContext<S, A>) throws {
    try handler(coordinator, context)
  }
}
