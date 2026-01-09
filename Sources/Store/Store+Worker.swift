//


import Foundation


extension Store {
  
  /// Executes the dispatch pipeline. Internal to Store.
  @MainActor
  final class Worker {
    
    // MARK: - Properties
    
    nonisolated
    let dispatcher: Dispatcher
    
    let middlewares: [AnyMiddleware<S, A>]
    let reducers: [AnyReducer<S, A>]
    let resolvers: [AnyResolver<S, A>]
    nonisolated
    let onLog: LogHandler<S, A>?
    
    private var process: ProcessHandler<S, A>?
    
    private var task: Task<Void, Never>?
    private var state: S
    
    // MARK: - Init
    
    init(
      initialState state: S,
      middlewares: [AnyMiddleware<S, A>],
      resolvers: [AnyResolver<S, A>],
      reducers: [AnyReducer<S, A>],
      onLog: LogHandler<S, A>? = nil
    ) {
      self.state = state
      self.middlewares = middlewares.reversed()
      self.resolvers = resolvers.reversed()
      self.reducers = reducers
      self.onLog = onLog
      self.dispatcher = Dispatcher()
      self.process = buildDispatchProcess()
      let events = dispatcher.events

      self.task = Task { [weak self] in
        for await event in events {
          guard let self else { return }
          if dispatcher.isCurrentGeneration(event.generation) {
            process?(state.readOnly,
                     event.action,
                     event.completion)
            dispatcher.decrease(id: event.action.id)
          } else {
            event.completion?(state.readOnly)
          }
        }
      }
    }
    
    @Sendable
    nonisolated
    func dispatch(
      maxDispatchable limit: UInt = 0,
      actions: [A]
    ) {
      for action in actions {
        dispatcher.tryEnqueue(
          id: action.id,
          limit: limit,
          (action: action, completion: nil)
        )
      }
    }
    
    @discardableResult @Sendable
    nonisolated
    func dispatch(
      maxDispatchable limit: UInt = 0,
      _ action: A,
      completion: ActionHandler<S>? = nil
    ) -> Bool {
      dispatcher.tryEnqueue(
        id: action.id,
        limit: limit,
        (action: action, completion: completion)
      )
    }
    
    // MARK: - Pipeline
    
    private func buildDispatchProcess() -> ProcessHandler<S, A> {
      let middlewares = self.middlewares
      let resolvers = self.resolvers
      let reducers = self.reducers
      let dispatcher = self.dispatcher
      let state = self.state
      let readOnly = self.state.readOnly
      let onLog = self.onLog

      // Dispatch — wraps dispatcher for context injection
      let dispatch: ReduxDispatch<A> = { limit, actions in
        for action in actions {
          dispatcher.tryEnqueue(id: action.id, limit: limit, (action: action, completion: nil))
        }
      }
      
      // 1. Reduce — iterates all reducers in forward order
      let reduceChain: ReduceChain<S, A> = { action, completion in
        for reducer in reducers {
          let start: ContinuousClock.Instant = .now
          let context = ReducerContext<S, A>(state, action)
          let exit = reducer.reduce(context)
          onLog?(.reducer(reducer.id, action, .now - start, exit))
        }
        completion?(readOnly)
      }
      
      // 2. Resolve chain — folds resolvers, first handler wins
      let resolveChain: ResolveChain<S, A> = { error, action, origin, completion in
        let resolver: @MainActor (SendableError, A) -> Void = { error, action in
          onLog?(.resolver("default", action, .zero, .exit(.failure(error)), error))
          completion?(readOnly)
        }
        let chain = resolvers.reduce(resolver) { next, resolver in
          { error, action in
            let start: ContinuousClock.Instant = .now
            let context = ResolverContext<S, A>(
              state: readOnly,
              action: action,
              error: error,
              origin: origin,
              dispatch: dispatch
            )
            let exitStatus = resolver.run(context)

            onLog?(.resolver(resolver.id, action, .now - start, exitStatus, error))

            switch exitStatus {
            case .next, .defaultNext:
              next(error, action)
            case .nextAs(let newError, let newAction):
              next(newError, newAction)
            case .reduce:
              reduceChain(action, completion)
            case .reduceAs(let newAction):
              reduceChain(newAction, completion)
            case .exit:
              completion?(readOnly)
            }
          }
        }
        chain(error, action)
      }
      
      // Run task — fire-and-forget with async timing and error routing to resolveChain
      let runTask: RunTask<S, A> = { body, action, middlewareId in
        Task {
          let taskStart: ContinuousClock.Instant = .now
          do {
            try await body(readOnly)
            await MainActor.run {
              onLog?(.middleware(middlewareId, action, .now - taskStart, .exit(.success)))
            }
          } catch {
            await MainActor.run {
              onLog?(.middleware(middlewareId, action, .now - taskStart, .resolve(error)))
              resolveChain(error, action, middlewareId, nil)
            }
          }
        }
      }

      // Run deferred task — handler receives resume, async timing logged on resume
      let runDeferredTask: RunDeferredTask<S, A> = { handler, next, action, middlewareId, completion in
        let taskStart: ContinuousClock.Instant = .now
        let resume: ResumeHandler<A> = { resumeExit in
          Task { @MainActor in
            onLog?(.middleware(middlewareId, action, .now - taskStart, MiddlewareExit(from: resumeExit)))

            switch resumeExit {
            case .next: next(action)
            case .nextAs(let newAction): next(newAction)
            case .resolve(let error): resolveChain(error, action, middlewareId, completion)
            case .exit(.success): reduceChain(action, completion)
            case .exit(.failure): completion?(readOnly)
            }
          }
        }
        handler(resume)
      }
      
      // 3. Middleware chain — folds middlewares around reduce
      let middlewareChain: MiddlewareChain<S, A> = { _, action, completion in
        let seed: @MainActor (A) -> Void = { action in reduceChain(action, completion) }
        let chain = middlewares.reduce(seed) { next, middleware in
          { action in
            let start: ContinuousClock.Instant = .now
            let context = MiddlewareContext<S, A>(
              state: readOnly,
              dispatch: dispatch,
              action: action
            )
            let exit: MiddlewareExit<S, A>

            do {
              exit = try middleware.run(context)
            } catch {
              onLog?(.middleware(middleware.id, action, .now - start, .resolve(error)))
              resolveChain(error, action, middleware.id, completion)
              return
            }
            
            switch exit {
            case .task, .deferred: break
            // .next, .defaultNext, .nextAs, .resolve, .exit
            default:
              onLog?(.middleware(middleware.id, action, .now - start, exit))
            }

            switch exit {
            case .next, .defaultNext:
              next(action)
            case .nextAs(let newAction):
              next(newAction)
            case .resolve(let error):
              resolveChain(error, action, middleware.id, completion)
            case .exit(.success):
              reduceChain(action, completion)
            case .exit(.failure):
              completion?(readOnly)
              return
            case .task(let body):
              runTask(body, action, middleware.id)
              next(action)
            case .deferred(let handler):
              runDeferredTask(handler, next, action, middleware.id, completion)
            }
          }
        }
        chain(action)
      }

      return middlewareChain
    }
  }
}
