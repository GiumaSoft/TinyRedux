//

import Foundation


@MainActor
public func combine<S, A>(
  _ reducers: Reducer<S, A>...
) -> Reducer<S, A> {
  
  Reducer { state, action in
    reducers.forEach {
      $0.reduce(&state, action)
    }
  }
}


@MainActor
public func pullback<LS, GS, LA, GA>(
  _ reducer: Reducer<LS, LA>,
  toState state: WritableKeyPath<GS, LS>,
  toAction action: WritableKeyPath<GA, LA?>
) -> Reducer<GS, GA> {
  
  Reducer { gs, ga in
    guard let la = ga[keyPath: action] else { return }
    reducer.reduce(&gs[keyPath: state], la)
  }
}


@MainActor
public func logger<S, A>(
  _ reducer: Reducer<S, A>
) -> Reducer<S, A> {
  Reducer { state, action in
    reducer.reduce(&state, action)
    print("ℹ️ [[ Action ]]: \(action)")
    //let newState = state
    // print("State:")
    // print("\(newState)")
    print("---")
  }
}

public func pullback<LS, GS, LA, GA>(
  _ middleware: AnyMiddleware<LS, LA>,
  toState state: WritableKeyPath<GS, LS>,
  toAction action: WritableKeyPath<GA, LA?>,
  toGlobalAction tGA: @escaping (LA) -> GA
) -> AnyMiddleware<GS, GA> {
  
  AnyMiddleware<GS, GA> { gs, gd, gn, ga in
    if
      let la: LA = ga[keyPath: action] {
      let ls: () -> LS = { gs()[keyPath: state]  }
      let ld: (LA) -> Void = { la in gd(tGA(la)) }
      let ln: (LA) -> Void = { la in gn(tGA(la)) }
      
      middleware.run(RunArguments(ls, ld, ln, la))
    } else {
      gn(ga)
    }
  }
}


public func logger<S, A>(
  _ middleware: AnyMiddleware<S, A>
) -> AnyMiddleware<S, A> {
  AnyMiddleware { getState, dispatch, next, action in
    // Customize here your logs pre middleware invocation.
    middleware.run(RunArguments(getState, dispatch, next, action))
  }
}
