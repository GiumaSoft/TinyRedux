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
      options: StoreOptions = .init(),
      onLog: LogHandler<S, A>? = nil
    ) {
      self.state = state
      self.middlewares = middlewares.reversed()
      self.resolvers = resolvers.reversed()
      self.reducers = reducers
      self.onLog = onLog
      self.dispatcher = Dispatcher(capacity: options.dispatcherCapacity)

      let events = dispatcher.events
      self.task = Task { @MainActor [weak self] in
        guard let self else { return }
        process = buildDispatchProcess()
        for await event in events {
          defer { dispatcher.consume(id: event.action.id) }

          guard dispatcher.isCurrentGeneration(event.generation) else {
            event.onSnapshot?.continuation.resume(returning:
              .failure(EnqueueFailure.staleGeneration))
            continue
          }

          if Task.isCancelled, event.onSnapshot != nil {
            event.onSnapshot!.continuation.resume(returning:
              .failure(CancellationError()))
            continue
          }

          let deferSnapshot: SnapshotHandler<S>?
          if let onSnapshot = event.onSnapshot {
            deferSnapshot = { result in
              switch result {
              ///
              case .success(let readOnly):
                do {
                  let data = try onSnapshot.snapshot(readOnly)
                  onSnapshot.continuation.resume(returning: .success(data))
                } catch {
                  onSnapshot.continuation.resume(returning: .failure(error))
                }
              ///
              case .failure(let error):
                onSnapshot.continuation.resume(returning: .failure(error))
              }
            }
          } else {
            deferSnapshot = nil
          }

          process?(state.readOnly, event.action, deferSnapshot)
        }
      }
    }


    @Sendable
    nonisolated
    func dispatch(
      maxDispatchable limit: UInt = 0,
      actions: [A]
    ) {
      let onLog = self.onLog
      for action in actions {
        let result = dispatcher.tryEnqueue(
          id: action.id,
          limit: limit,
          (action: action, onSnapshot: nil)
        )
        if case let .failure(error) = result, error != .staleGeneration {
          Task { @MainActor in
            onLog?(.store("Store discarded action due to \(error.reason)."))
          }
        }
      }
    }

    @Sendable
    nonisolated
    func dispatch(_ action: A, onSnapshot: ReadOnlySnapshot<S>) {
      let onLog = self.onLog
      let result = dispatcher.tryEnqueue(
        id: action.id,
        limit: 0,
        (action: action, onSnapshot: onSnapshot)
      )
      if case let .failure(error) = result {
        onSnapshot.continuation.resume(returning: .failure(error))
        if error != .staleGeneration {
          Task { @MainActor in
            onLog?(.store("Store discarded action due to \(error.reason)."))
          }
        }
      }
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
          let result = dispatcher.tryEnqueue(
            id: action.id,
            limit: limit,
            (action: action, onSnapshot: nil)
          )
          if case let .failure(error) = result, error != .staleGeneration {
            Task { @MainActor in
              onLog?(.store("Store discarded action due to \(error.reason)."))
            }
          }
        }
      }

      // Subscription chain — evaluates registry entries post-reducer, fires matched entries.
      let subscriptionChain: SubscriptionChain = {
        guard !registry.entries.isEmpty else {

          return
        }

        var matched: [Subscriptions.Entry] = []
        registry.entries.removeAll { entry in
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

          let result = dispatcher.tryEnqueue(
            id: action.id,
            limit: 0,
            generation: entry.generation,
            (action: action, onSnapshot: nil)
          )

          switch result {
          ///
          case .success:
            onLog?(.subscription(.executed(entry.registeredBy, entry.id, entry.origin, .now - start, action)))
          ///
          case let .failure(error) where error != .staleGeneration:
            onLog?(.store("Store discarded action due to \(error.reason)."))
          ///
          case .failure:
            break
          }
        }
      }

      // 1. Reduce — iterates all reducers in forward order
      let reduceChain: ReduceChain<S, A> = { action, deferSnapshot in
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
            deferSnapshot?(.success(readOnly))

            return
          }
        }
        subscriptionChain()
        deferSnapshot?(.success(readOnly))
      }

      // 2. Resolve chain — folds resolvers, first handler wins.
      let resolveChain: ResolveChain<S, A> = { error, action, origin, deferSnapshot in
        let defaultResolver: @MainActor (SendableError, A) -> Void = { error, action in
          onLog?(.resolver("default", action, .zero, .exit(.failure(error)), error))
          deferSnapshot?(.failure(error))
        }
        let chain = resolvers.reduce(defaultResolver) { next, resolver in
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
              reduceChain(action, deferSnapshot)
            ///
            case .reduceAs(let newAction):
              reduceChain(newAction, deferSnapshot)
            ///
            case .exit:
              deferSnapshot?(.success(readOnly))
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
      let runDeferredTask: RunDeferredTask<S, A> = { handler, next, action, middlewareId, deferSnapshot in
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
                resolveChain(error, action, middlewareId, deferSnapshot)
              ///
              case .exit(.success):
                reduceChain(action, deferSnapshot)
              ///
              case .exit(.done):
                deferSnapshot?(.success(readOnly))
              ///
              case .exit(.failure(let error)):
                deferSnapshot?(.failure(error))
              }
            }
          } catch {
            await MainActor.run {
              onLog?(.middleware(middlewareId, action, .now - taskStart, .resolve(error)))
              resolveChain(error, action, middlewareId, deferSnapshot)
            }
          }
        }
      }

      // 3. Middleware chain — folds middlewares around reduce
      let middlewareChain: MiddlewareChain<S, A> = { _, action, deferSnapshot in
        let seed: @MainActor (A) -> Void = { action in reduceChain(action, deferSnapshot) }
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
              resolveChain(error, action, middleware.id, deferSnapshot)

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
              resolveChain(error, action, middleware.id, deferSnapshot)
            ///
            case .exit(.success):
              reduceChain(action, deferSnapshot)
            ///
            case .exit(.done):
              deferSnapshot?(.success(readOnly))

              return
            ///
            case .exit(.failure(let error)):
              deferSnapshot?(.failure(error))

              return
            ///
            case .task(let body):
              runTask(body, action, middleware.id)
              next(action)
            ///
            case .deferred(let handler):
              runDeferredTask(handler, next, action, middleware.id, deferSnapshot)
            }
          }
        }
        chain(action)
      }

      return middlewareChain
    }
  }
}
