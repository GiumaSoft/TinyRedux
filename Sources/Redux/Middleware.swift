//


import Foundation


public typealias RunArguments<S: Sendable, A: Equatable> = (getState: () -> S, dispatch: (A) -> Void, next: (A) -> Void, action: A)


public class Middleware<S, A> where S: Sendable, A: Equatable {
  private let handler: (RunArguments<S, A>) -> Void
  
  public init(handler: @escaping (RunArguments<S, A>) -> Void) {
    self.handler = handler
  }
  
  public func run(_ args: RunArguments<S, A>) {
    self.handler(args)
  }
}

public class StatedMiddleware<T, S, A>: Middleware<S, A> where S: Sendable, A: Equatable {
  private let model: T
  private let handler: (T, RunArguments<S, A>) -> Void
  
  public init(model: T, handler: @escaping (T, RunArguments<S, A>) -> Void) {
    self.model = model
    self.handler = handler
    super.init { args in
      handler(model, args)
    }
  }
  
  override public func run(_ args: RunArguments<S, A>) {
    self.handler(model, args)
  }
}

extension Middleware {
  public func lift<GS, GA>(
    toState state: WritableKeyPath<GS, S>,
    toAction action: WritableKeyPath<GA, A?>,
    toGlobalAction tGA: @escaping (A) -> GA
  ) -> Middleware<GS, GA> where GS: Sendable, GA: Equatable {

    Middleware<GS, GA> { args in
      let (gs, gd, gn, ga) = args

      if let la = ga[keyPath: action] {
        self.run(
          RunArguments(
            { gs()[keyPath: state] },
            { la in gd(tGA(la)) },
            { la in gn(tGA(la)) },
            la
          )
        )
      } else {
        gn(ga)
      }
    }
  }
}
