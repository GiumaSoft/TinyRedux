// Store+DispatchWorker.swift
// TinyRedux

import Foundation

extension Store {
  
  /// Executes the dispatch pipeline. Internal to Store.
  @MainActor
  final class DispatchWorker {
    
    // MARK: - Properties
    
    nonisolated let dispatcher: Dispatcher
    
    let middlewares: [AnyMiddleware<S, A>]
    let reducers: [AnyReducer<S, A>]
    let resolvers: [AnyResolver<S, A>]
    let onLog: (@Sendable (Log) -> Void)?
    
    private var dispatchProcess: (@MainActor (S.ReadOnly, A) -> Void)?
    
    private var task: Task<Void, Never>?
    weak var store: Store?
    private var state: S { store!._state }
    
    // MARK: - Init
    
    init(
      middlewares: [AnyMiddleware<S, A>],
      resolvers: [AnyResolver<S, A>],
      reducers: [AnyReducer<S, A>],
      onLog: (@Sendable (Log) -> Void)? = nil
    ) {
      self.middlewares = middlewares.reversed()
      self.resolvers = resolvers.reversed()
      self.reducers = reducers
      self.onLog = onLog
      self.dispatcher = Dispatcher()
      self.dispatchProcess = buildDispatchProcess()
      let actions = dispatcher.actions
      
      self.task = Task { [weak self] in
        for await element in actions {
          guard let self, let store = self.store else { return }
          self.dispatchProcess?(store._state.readOnly, element.action)
          element.completion?(store._state.readOnly)
          self.dispatcher.decrease(id: element.action.id)
        }
      }
    }
    
    @Sendable
    nonisolated
    func dispatch(
      maxDispatchable limit: UInt = 0,
      actions: [A]
    )
    {
      for action in actions {
        dispatcher.tryEnqueue(id: action.id, limit: limit, (action: action, completion: nil))
      }
    }
    
    @Sendable
    @discardableResult
    nonisolated
    func dispatch(
      maxDispatchable limit: UInt = 0,
      _ action: A,
      completion: (@Sendable (S.ReadOnly) -> Void)? = nil
    ) -> Bool
    {
      dispatcher.tryEnqueue(id: action.id, limit: limit, (action: action, completion: completion))
    }
    
    nonisolated
    func runTask(
      _ readOnly: S.ReadOnly,
      _ job: @escaping @Sendable (S.ReadOnly) async throws -> Void,
      _ resolve: @escaping @MainActor (any Error) -> Void
    )
    {
      Task {
        do {
          try await job(readOnly)
        } catch {
          await resolve(error)
        }
      }
    }
    
    // MARK: - Pipeline
    
    private func buildDispatchProcess() -> @MainActor (S.ReadOnly, A) -> Void {
      let middlewares = self.middlewares
      let reducers = self.reducers
      let resolvers = self.resolvers
      let onLog = self.onLog
      
      return { [unowned self] readOnly, action in
        
        // 1. Reduce: applies all reducers in forward order.
        let reduce: @MainActor (A) -> Void = { [unowned self] action in
          let currentState = self.state
          for reducer in reducers {
            let complete: (Bool) -> Void
            if let onLog {
              let start = ContinuousClock.now
              complete = { succeeded in
                onLog(
                  .reducer(
                    reducer.id,
                    action,
                    ContinuousClock.now - start,
                    succeeded
                  )
                )
              }
            } else {
              complete = { _ in }
            }
            let context = ReducerContext<S, A>(
              state: currentState,
              action: action,
              complete: complete
            )
            reducer.reduce(context)
          }
        }
        
        // 2. Resolve chain: built via fold, runs in user-supplied order.
        let resolveChain: @MainActor @Sendable (any Error, A, String) -> Void = {
          [unowned self] error, action, origin in
          let resolve: @MainActor (any Error, A) -> Void = { _, _ in }
          let chain = resolvers.reduce(resolve) { next, resolver in
            { [unowned self] error, action in
              
              let complete: @Sendable (Bool) -> Void
              if let onLog {
                let start = ContinuousClock.now
                complete = { succeeded in
                  onLog(
                    .resolver(
                      resolver.id,
                      action,
                      ContinuousClock.now - start,
                      succeeded,
                      error
                    )
                  )
                }
              } else {
                complete = { _ in }
              }
              
              let context = ResolverContext<S, A>(
                state: readOnly,
                action: action,
                error: error,
                origin: origin,
                dispatch: { [unowned self] limit, actions in
                  self.dispatch(maxDispatchable: limit, actions: actions)
                },
                complete: complete,
                _next: { error, action in next(error, action) }
              )
              resolver.run(context)
            }
          }
          chain(error, action)
        }
        
        // 3. Middleware chain: built via fold, sync — async work through task launcher.
        let middlewareChain: @MainActor @Sendable (A) -> Void = middlewares.reduce(reduce) { next, middleware in
          { [unowned self] action in
            
            let complete: @Sendable (Result<Bool, any Error>) -> Void
            if let onLog {
              let start = ContinuousClock.now
              complete = { result in
                onLog(
                  .middleware(
                    middleware.id,
                    action,
                    ContinuousClock.now - start,
                    result
                  )
                )
              }
            } else {
              complete = { _ in }
            }
            
            let context = MiddlewareContext<S, A>(
              action: action,
              dispatch: { limit, actions in
                self.dispatch(maxDispatchable: limit, actions: actions)
              },
              resolve: { error in
                resolveChain(error, action, middleware.id)
              },
              task: { [unowned self] job in
                self.runTask(readOnly, job) { error in
                  resolveChain(error, action, middleware.id)
                }
              },
              complete: complete,
              _next: next
            )

            do {
              try middleware.run(context)
            } catch {
              context.complete(.failure(error))
              resolveChain(error, action, middleware.id)
            }
          }
        }

        middlewareChain(action)
      }
    }
  }
}
