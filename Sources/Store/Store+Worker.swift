//


import Foundation


extension Store {
  
  /// Executes the dispatch pipeline. Internal to Store.
  final class Worker: Sendable {
    
    // MARK: - Properties
    
    nonisolated
    let dispatcher: Dispatcher
    let middlewares: [AnyMiddleware<S, A>]
    let reducers: [AnyReducer<S, A>]
    let resolvers: [AnyResolver<S, A>]
    nonisolated
    let onLog: LogHandler<S, A>?
    
    @MainActor
    private var process: ProcessHandler<S, A>?
    @MainActor
    private var task: Task<Void, Never>?
    @MainActor
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
      
      let events = dispatcher.events
      self.task = Task { @MainActor [weak self] in
        guard let self else { return }
        process = buildDispatchProcess()
        for await event in events {
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
    
    @MainActor
    private func buildDispatchProcess() -> ProcessHandler<S, A> {
      let middlewares = self.middlewares
      let resolvers = self.resolvers
      let reducers = self.reducers
      let dispatcher = self.dispatcher
      let state = self.state
      let readOnly = self.state.readOnly
      let onLog = self.onLog
      let registry = Subscriptions()

      // Dispatch — wraps dispatcher for context injection
      let dispatch: ReduxDispatch<A> = { limit, actions in
        for action in actions {
          dispatcher.tryEnqueue(id: action.id, limit: limit, (action: action, completion: nil))
        }
      }

      // Subscription chain — evaluates registry entries post-reducer, fires matched entries.
      // Race-safe: the enqueue uses `tryEnqueueIfCurrentGeneration` so a concurrent
      // `flush()`/`suspend()` between match and dispatch invalidates the enqueue atomically.
      let subscriptionChain: SubscriptionChain = {
        guard !registry.entries.isEmpty else {

          return
        }

        var matched: [Subscriptions.Entry] = []
        registry.entries.removeAll { entry in
          /// Stale entries (generation bumped by flush/suspend) are removed silently, no fire.
          guard dispatcher.isCurrentGeneration(entry.generation) else {

            return true
          }

          if entry.when(readOnly) {
            matched.append(entry)

            return true
          }

          return false
        }

        for entry in matched {
          let start: ContinuousClock.Instant = .now
          let action = entry.then(readOnly)

          /// Atomic conditional enqueue: check + yield under single lock — closes the
          /// race with `flush()`/`suspend()` nonisolated concurrent bumps.
          let enqueued = dispatcher.tryEnqueue(
            id: action.id,
            limit: 0,
            generation: entry.generation,
            (action: action, completion: nil)
          )

          if enqueued {
            onLog?(.subscription(.executed(entry.registeredBy, entry.id, entry.origin, .now - start, action)))
          }
        }
      }

      // 1. Reduce — iterates all reducers in forward order
      let reduceChain: ReduceChain<S, A> = { action, completion in
        for reducer in reducers {
          let start: ContinuousClock.Instant = .now
          let context = ReducerContext<S, A>(state, action)
          let exit = reducer.reduce(context)

          switch exit {
          ///
          case .defaultNext:
            break
          ///
          default:
            onLog?(.reducer(reducer.id, action, .now - start, exit))
          }

          switch exit {
          ///
          case .next, .defaultNext: break
          ///
          case .done:
            subscriptionChain()
            completion?(readOnly)

            return
          }
        }
        subscriptionChain()
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

            switch exitStatus {
            ///
            case .defaultNext:
              break
            ///
            default:
              onLog?(.resolver(resolver.id, action, .now - start, exitStatus, error))
            }

            switch exitStatus {
            ///
            case .next, .defaultNext:
              next(error, action)
            ///
            case .nextAs(let newError, let newAction):
              next(newError, newAction)
            ///
            case .reduce:
              reduceChain(action, completion)
            ///
            case .reduceAs(let newAction):
              reduceChain(newAction, completion)
            ///
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

      // Run deferred task — async handler with state access, single Task pattern
      let runDeferredTask: RunDeferredTask<S, A> = { handler, next, action, middlewareId, completion in
        Task {
          let taskStart: ContinuousClock.Instant = .now
          do {
            let resumeExit = try await handler(readOnly)
            await MainActor.run {
              onLog?(.middleware(middlewareId, action, .now - taskStart, MiddlewareExit(from: resumeExit)))
              switch resumeExit {
              ///
              case .next:
                next(action)
              ///
              case .nextAs(let newAction):
                next(newAction)
              ///
              case .resolve(let error):
                resolveChain(error, action, middlewareId, completion)
              ///
              case .exit(.success):
                reduceChain(action, completion)
              ///
              case .exit(.done):
                completion?(readOnly)
              ///
              case .exit(.failure):
                completion?(readOnly)
              }
            }
          } catch {
            await MainActor.run {
              onLog?(.middleware(middlewareId, action, .now - taskStart, .resolve(error)))
              resolveChain(error, action, middlewareId, completion)
            }
          }
        }
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
              action: action,
              register: { id, origin, when, then in
                let registerStart: ContinuousClock.Instant = .now
                registry.register(Subscriptions.Entry(
                  id: id,
                  origin: origin,
                  registeredBy: middleware.id,
                  generation: dispatcher.currentGeneration,
                  when: when,
                  then: then
                ))
                onLog?(.subscription(.subscribed(middleware.id, id, origin, .now - registerStart)))
              },
              unregister: { id in
                let unregisterStart: ContinuousClock.Instant = .now
                if registry.unregister(id: id) {
                  onLog?(.subscription(.unsubscribed(middleware.id, id, .now - unregisterStart)))
                }
              }
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
            ///
            case .task, .deferred, .defaultNext:
              break
            ///
            default:
              onLog?(.middleware(middleware.id, action, .now - start, exit))
            }

            switch exit {
            ///
            case .next, .defaultNext:
              next(action)
            ///
            case .nextAs(let newAction):
              next(newAction)
            ///
            case .resolve(let error):
              resolveChain(error, action, middleware.id, completion)
            ///
            case .exit(.success):
              reduceChain(action, completion)
            ///
            case .exit(.done):
              completion?(readOnly)

              return
            ///
            case .exit(.failure):
              completion?(readOnly)

              return
            ///
            case .task(let body):
              runTask(body, action, middleware.id)
              next(action)
            ///
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
