// swift-tools-version: 6.0


import Foundation


extension Store {
  /// Builds the composed dispatch processor that wires middleware, resolver, and reducer chains,
  /// ensuring logging and timing hooks are applied while preserving action order during execution
  /// on the MainActor for each. Builds the middleware chain and reducer pipeline.
  func buildDispatchProcess() -> @MainActor (A) -> Void {
    /// Process reducers.
    let reduce: (A) -> Void = { [unowned self] action in
      let currentState = self.state
      let reduce: (Reducer<S, A>, A, @escaping @MainActor @Sendable (Bool) -> Void) -> Void = { reducer, action, complete in
        let context = ReducerContext<S, A>(
          state: currentState,
          action: action,
          complete: complete
        )
        reducer.reduce(context)
      }
      
      if let onLog = self.onLog {
        for reducer in self.reducers {
          measurePerformance { runTime in
            reduce(reducer, action) { succeded in
              onLog(.reducer(reducer.id, action, runTime(), succeded))
            }
          }
        }
      } else {
        for reducer in self.reducers {
          reduce(reducer, action, { _ in })
        }
      }
    }
    
    /// Process resolvers.
    let resolve: (any Error, A, ReduxErrorOrigin) -> Void = { [unowned self] error, action, origin in
      if self.resolvers.isEmpty {
        if let onLog = self.onLog {
          self.measurePerformance { runTime in
            switch origin {
            case .middleware(let middlewareId):
              onLog(.middleware(middlewareId, error, action, runTime(), false))
            }
          }
        }
        return
      }
      
      let resolversChain: (any Error, A) -> Void = self.resolvers.reduce(
        { _, action in
          reduce(action)
        }
      ) { [unowned self] next, resolver in
        { [unowned self] error, action in
          var doNext = true
          let runProcess: (@escaping @MainActor (Bool) -> Void) -> Void = { complete in
            let context = ResolverContext<S, A>(
              state: self.state.readOnly,
              dispatch: self.dispatch,
              error: error,
              action: action,
              origin: origin,
              next: { error, action in
                if doNext {
                  doNext = false
                  next(error, action)
                }
              },
              complete: complete
            )
            
            resolver.run(context)
          }
          
          if let onLog = self.onLog {
            self.measurePerformance { runTime in
              runProcess() { succeded in
                switch origin {
                case .middleware(let middlewareId):
                  onLog(.resolver(resolver.id, middlewareId, error, action, runTime(), succeded))
                }
              }
            }
          } else {
            runProcess({ _ in })
          }
        }
      }
      
      resolversChain(error, action)
    }
    
    /// Process middlewares.
    let process: @MainActor (A) -> Void = { [unowned self] action in
      
      if self.middlewares.isEmpty {
        reduce(action)
        return
      }
      
      let middlewaresChain: (A) -> Void = self.middlewares.reduce(
        reduce
      ) { [unowned self] next, middleware in
        { [unowned self] action in
          var doNext = true
          let runProcess: (@escaping @MainActor (Bool) -> Void) -> Void = { complete in
            let context = MiddlewareContext<S, A>(
              state: self.state.readOnly,
              dispatch: self.dispatch,
              next: { action in
                if doNext {
                  doNext = false
                  next(action)
                }
              },
              action: action,
              complete: complete,
              resolve: { error in
                resolve(error, action, .middleware(middleware.id))
              }
            )
            
            do {
              try middleware.run(context)
            } catch {
              resolve(error, action, .middleware(middleware.id))
            }
          }
          
          if let onLog = self.onLog {
            self.measurePerformance { runTime in
              runProcess() { succeded in
                onLog(.middleware(middleware.id, nil, action, runTime(), succeded))
              }
            }
          } else {
            runProcess({ _ in })
          }
        }
      }
      
      middlewaresChain(action)
    }
    
    return process
  }
}
