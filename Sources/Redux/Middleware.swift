//


import Foundation


/// Middleware
///
public typealias RunArguments<S: Sendable, A: Sendable & Equatable> = (getState: @MainActor @Sendable () async -> S, dispatch: @Sendable (A) -> Void, next: @MainActor @Sendable (A) async throws -> Void, action: A)

public protocol Middleware: Sendable {
  associatedtype S: Sendable
  associatedtype A: Sendable & Equatable
  
  @MainActor
  @Sendable
  func run(_ args: RunArguments<S, A>) async throws
}

@frozen public struct AnyMiddleware<S, A>: Sendable where S: Sendable, A: Sendable & Equatable {
  let handler: @MainActor @Sendable (RunArguments<S, A>) async throws -> Void
  
  public init(handler: @MainActor @Sendable @escaping (RunArguments<S, A>) async throws -> Void) {
    self.handler = handler
  }
  
  public nonisolated init<M>(_ middleware: M) where M: Middleware, M.S == S, M.A == A {
    self.handler = { args in try await middleware.run(args) }
  }
  
  public nonisolated init<M, LS, LA>(
    _ middleware: M,
    toState state: WritableKeyPath<S, LS> & Sendable,
    toAction action: WritableKeyPath<A, LA?> & Sendable,
    toGlobalAction tGA: @Sendable @escaping (LA) -> A
  ) where M: Middleware, M.S == LS, M.A == LA {
    self.handler = { args in
      let (gs, gd, gn, ga) = args
      
      if let la = ga[keyPath: action] {
        try await middleware.run(
          RunArguments(
            { await gs()[keyPath: state] },
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
  @Sendable
  public func run(_ args: RunArguments<S, A>) async throws {
    try await self.handler(args)
  }
}

@frozen public struct StatedMiddleware<T, S, A>: Middleware where T: Sendable, S: Sendable, A: Sendable & Equatable {
  private let coordinator: T
  private let handler: @MainActor @Sendable (T, RunArguments<S, A>) async throws -> Void
  
  public init(coordinator: T, handler: @MainActor @Sendable @escaping (T, RunArguments<S, A>) async throws -> Void) {
    self.coordinator = coordinator
    self.handler = handler
  }
  
  @MainActor
  @Sendable
  public func run(_ args: RunArguments<S, A>) async throws {
    try await self.handler(coordinator, args)
  }
}
