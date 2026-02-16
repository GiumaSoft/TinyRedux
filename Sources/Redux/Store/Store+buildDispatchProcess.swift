// swift-tools-version: 6.0


import Foundation


extension Store {
  /// Builds the composed dispatch processor that wires middleware, resolver, and reducer chains,
  /// ensuring logging and timing hooks are applied while preserving action order during execution
  /// on the MainActor for each. Builds the middleware chain and reducer pipeline.
  func buildDispatchProcess() -> @MainActor (EnqueuedAction) -> Void {
    /// Process reducers.
    let reduce: (A, @escaping @MainActor (Result<S.ReadOnly, ReduxError>) -> Void) -> Void = { [unowned self] action, finish in
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

      finish(.success(self.state.readOnly))
    }
    
    /// Process resolvers.
    let resolve: (any Error, A, ReduxErrorOrigin, @escaping @MainActor (Result<S.ReadOnly, ReduxError>) -> Void) -> Void = {
      [unowned self] error, action, origin, finish in

      if self.resolvers.isEmpty {
        if let onLog = self.onLog {
          self.measurePerformance { runTime in
            switch origin {
            case .middleware(let middlewareId):
              onLog(.middleware(middlewareId, error, action, runTime(), false))
            }
          }
        }
        finish(.failure(.storeDropActionByUnresolvedError(error)))
        return
      }
      
      for resolver in self.resolvers {
        let runProcess: (@escaping @MainActor (Bool) -> Void) -> ResolverOutcome<A> = { complete in
          let context = ResolverContext<S, A>(
            state: self.state.readOnly,
            dispatch: self.dispatch,
            error: error,
            action: action,
            origin: origin,
            complete: complete
          )
          
          return resolver.run(context)
        }
        
        let outcome: ResolverOutcome<A>
        if let onLog = self.onLog {
          var measuredOutcome: ResolverOutcome<A> = .next
          self.measurePerformance { runTime in
            measuredOutcome = runProcess { succeded in
              switch origin {
              case .middleware(let middlewareId):
                onLog(.resolver(resolver.id, middlewareId, error, action, runTime(), succeded))
              }
            }
          }
          outcome = measuredOutcome
        } else {
          outcome = runProcess({ _ in })
        }

        switch outcome {
        case .retry(let action):
          self.dispatch(maxDispatchable: 0, action)
          finish(.success(self.state.readOnly))
          
          return
        case .reduce(let action):
          reduce(action, finish)
          
          return
        case .next:
          continue
        case .fail:
          finish(.failure(.storeDropActionByUnresolvedError(error)))
          return
        }
      }

      finish(.failure(.storeDropActionByUnresolvedError(error)))
    }
    
    /// Process middlewares.
    let process: @MainActor (EnqueuedAction) -> Void = { [unowned self] enqueued in
      let action = enqueued.action
      var isCompleted = false
      let finish: @MainActor (Result<S.ReadOnly, ReduxError>) -> Void = { result in
        guard !isCompleted else { return }
        isCompleted = true
        enqueued.completion?(result)
      }

      if self.middlewares.isEmpty {
        reduce(action, finish)
        return
      }
      
      let middlewaresChain: (A) -> Void = self.middlewares.reduce(
        { action in
          reduce(action, finish)
        }
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
                resolve(error, action, .middleware(middleware.id), finish)
              }
            )
            
            do {
              try middleware.run(context)
            } catch {
              resolve(error, action, .middleware(middleware.id), finish)
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
