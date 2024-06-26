//


import Foundation


public typealias RunArguments<S, A> = (getState: () -> S, dispatch: (A) -> Void, next: (A) -> Void, action: A)

public protocol Middleware {
  associatedtype S
  associatedtype A: Equatable
  
  func run(_ args: RunArguments<S, A>) -> Void
}

public struct AnyMiddleware<S, A>: Middleware where A: Equatable {
  private let job: (RunArguments<S, A>) -> Void
  
  public init(job: @escaping (RunArguments<S, A>) -> Void) {
    self.job = job
  }
  
  public init<M: Middleware>(_ middleware: M) where M.S == S, M.A == A {
    self.job = middleware.run
  }
  
  public func run(_ args: RunArguments<S, A>) {
    self.job(args)
  }
}
