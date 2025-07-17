//


/// Middleware
///
///
public typealias RunArguments<S, A> = (state: S.ReadOnly, dispatch: @MainActor (A, Int) -> Void, next: @MainActor (A) throws -> Void, action: A) where S : ReduxS, A : ReduxA


public protocol AnyMiddleware: Sendable {
  associatedtype S: ReduxS
  associatedtype A: ReduxA
  
  @MainActor
  func run(_ args: RunArguments<S, A>) throws
}


@frozen public struct Middleware<S, A>: Sendable where S : ReduxS, A : ReduxA {
  
  private let handler: @Sendable @MainActor (RunArguments<S, A>) throws -> Void
  
  public init(handler: @escaping @Sendable @MainActor (RunArguments<S, A>) throws -> Void) {
    self.handler = handler
  }
  
  public init<M>(_ middleware: M) where M: AnyMiddleware, M.S == S, M.A == A {
    self.handler = { args in try middleware.run(args) }
  }
  
  public init<M, LS, LA>(
    _ middleware: M,
    toState state: KeyPath<S.ReadOnly, LS.ReadOnly> & Sendable,
    toAction action: KeyPath<A, LA?> & Sendable,
    toGlobalAction tGA: @escaping @Sendable (LA) -> A
  ) where M: AnyMiddleware,  M.S == LS, M.A == LA {
    self.handler = { args in
      let (gs, gd, gn, ga) = args
      
      if let la = ga[keyPath: action] {
        try middleware.run(
          RunArguments<LS, LA>(
            gs[keyPath: state],
            { la, limit in gd(tGA(la), limit) },
            { la in try gn(tGA(la)) },
            la
          )
        )
      } else {
        try gn(ga)
      }
    }
  }
  
  @MainActor
  public func run(_ args: RunArguments<S, A>) throws {
    try self.handler(args)
  }
}


@frozen public struct StatelessMiddleware<S, A>: AnyMiddleware where S : ReduxS, A : ReduxA {
  
  private let handler: @Sendable @MainActor  (RunArguments<S, A>) throws -> Void
  
  public init(handler: @escaping @Sendable @MainActor  (RunArguments<S, A>) throws -> Void) {
    self.handler = handler
  }
  
  public func run(_ args: RunArguments<S, A>) throws {
    try self.handler(args)
  }
}


@frozen public struct StatedMiddleware<T, S, A>: AnyMiddleware where T : Sendable, S : ReduxS, A : ReduxA  {
  
  private let handler: @Sendable @MainActor  (T, RunArguments<S, A>) throws -> Void
  private let coordinator: T
  
  public init(coordinator: T, handler: @escaping @Sendable @MainActor  (T, RunArguments<S, A>) throws -> Void) {
    self.coordinator = coordinator
    self.handler = handler
  }
  
  public func run(_ args: RunArguments<S, A>) throws {
    try self.handler(coordinator, args)
  }
}
