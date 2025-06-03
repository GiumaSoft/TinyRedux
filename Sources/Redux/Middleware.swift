//


import Foundation


/// Middleware
///
///
public typealias RunArguments<S, A> = (S.ReadOnly, dispatch: (A) -> Void, next: (A) async throws -> Void, action: A) where S : ReduxState, A : ReduxAction


public protocol AnyMiddleware: Sendable {
  associatedtype S: ReduxState
  associatedtype A: ReduxAction
  
  @MainActor
  func run(_ args: RunArguments<S, A>) async throws
}


@frozen public struct Middleware<S, A>: Sendable where S: ReduxState, A: ReduxAction {
  @MainActor
  private let handler: @MainActor @Sendable (RunArguments<S, A>) async throws -> Void
  
  public init(handler: @escaping @MainActor @Sendable (RunArguments<S, A>) async throws -> Void) {
    self.handler = handler
  }
  
  public init<M>(_ middleware: M) where M: AnyMiddleware, M.S == S, M.A == A {
    self.handler = { args in try await middleware.run(args) }
  }
  
  public init<M, LS, LA>(
    _ middleware: M,
    toState state: KeyPath<S.ReadOnly, LS.ReadOnly> & Sendable,
    toAction action: KeyPath<A, LA?> & Sendable,
    toGlobalAction tGA: @Sendable @escaping (LA) -> A
  ) where M: AnyMiddleware,  M.S == LS, M.A == LA {
    self.handler = { args in
      let (gs, gd, gn, ga) = args
      
      if let la = ga[keyPath: action] {
        try await middleware.run(
          RunArguments<LS, LA>(
            gs[keyPath: state],
            { la in gd(tGA(la)) },
            { la in try await gn(tGA(la)) },
            la
          )
        )
      } else {
        try await gn(ga)
      }
    }
  }
  
  @MainActor
  public func run(_ args: RunArguments<S, A>) async throws {
    try await self.handler(args)
  }
}

@frozen public struct StatelessMiddleware<S, A>: AnyMiddleware where S: ReduxState, A: ReduxAction {
  @MainActor
  private let handler: @MainActor @Sendable (RunArguments<S, A>) async throws -> Void
  
  public init(handler: @escaping @MainActor @Sendable (RunArguments<S, A>) async throws -> Void) {
    self.handler = handler
  }
  
  @MainActor
  public func run(_ args: RunArguments<S, A>) async throws {
    try await self.handler(args)
  }
}


@frozen public struct StatedMiddleware<T, S, A>: AnyMiddleware where T : Sendable, S : ReduxState, A : ReduxAction {
  @MainActor
  private let handler: @MainActor @Sendable (T, RunArguments<S, A>) async throws -> Void
  private let coordinator: T
  
  public init(coordinator: T, handler: @escaping @MainActor @Sendable (T, RunArguments<S, A>) async throws -> Void) {
    self.coordinator = coordinator
    self.handler = handler
  }
  
  @MainActor
  public func run(_ args: RunArguments<S, A>) async throws {
    try await self.handler(coordinator, args)
  }
}
