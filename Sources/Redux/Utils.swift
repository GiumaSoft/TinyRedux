//

import Foundation


@MainActor
public func combine<S, A>(
  _ reducers: Reducer<S, A>...
) -> Reducer<S, A> where S: Sendable, A: Equatable {
  
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
) -> Reducer<GS, GA> where LS: Sendable, GS: Sendable, LA: Equatable, GA: Equatable {
  
  Reducer { gs, ga in
    guard let la = ga[keyPath: action] else { return }
    reducer.reduce(&gs[keyPath: state], la)
  }
}

@MainActor
public func logger<S, A>(
  _ reducer: Reducer<S, A>,
  excludedActions actions: Array<A> = []
) -> Reducer<S, A> where S: Sendable, A: Equatable {
  Reducer { state, action in
    reducer.reduce(&state, action)
    
    print("ℹ️ [[ Action ]]: \(action)")
    print("---")
  }
}


//@MainActor
//public func logger<S, A>(
//  _ reducer: Reducer<S, A>,
//  excludedActions actions: Array<A> = [],
//  completion: @escaping (S, A) -> Void = { state, action in
//    print("ℹ️ [[ Action ]]: \(action)")
//    print("---")
//  }
//) -> Reducer<S, A> where A: Equatable {
//  Reducer { state, action in
//    reducer.reduce(&state, action)
//    
//    if !actions.contains(action) {
//      completion(state, action)
//    }
//  }
//}

public func pullback<LS, GS, LA, GA>(
  _ middleware: AnyMiddleware<LS, LA>,
  toState state: WritableKeyPath<GS, LS>,
  toAction action: WritableKeyPath<GA, LA?>,
  toGlobalAction tGA: @escaping (LA) -> GA
) -> AnyMiddleware<GS, GA> where LS: Sendable, GS: Sendable, LA: Equatable, GA: Equatable {
  
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


//public func logger<S, A>(
//  _ middleware: AnyMiddleware<S, A>
//) -> AnyMiddleware<S, A> where S: Sendable, A: Equatable {
//  AnyMiddleware { getState, dispatch, next, action in
//    // Customize here your logs pre middleware invocation.
//    middleware.run(RunArguments(getState, dispatch, next, action))
//  }
//}
//
//func logHandler<S, A>(state: S, action: A) -> Void {
//  print("ℹ️ [[ Action ]]: \(action)")
//  //let newState = state
//  // print("State:")
//  // print("\(newState)")
//  print("---")
//}
