// Store+Worker.swift
// TinyRedux

import Foundation

extension Store {

  /// Executes the dispatch pipeline. Internal to Store.
  @MainActor
  final class DispatchWorker {

    // MARK: - Type Aliases

    typealias DispatchElement = (action: Action, completion: (@Sendable (State.ReadOnly) -> Void)?)
    typealias Origin = ResolverContext<State, Action>.Origin
    typealias Complete = (Bool) -> Void
    typealias MiddlewareComplete = (Result<Bool, any Error>) -> Void
    typealias Dispatch = (UInt, Action...) -> Void
    typealias Resolve = (SendableError) -> Void
    typealias Reduce = @MainActor (Action) -> Void
    typealias ResolveNext = @MainActor (SendableError, Action) -> Void
    typealias ResolveChain = @MainActor (SendableError, Action, Origin) -> Void

    // MARK: - Properties

    nonisolated let dispatcher: Dispatcher

    let middlewares: [AnyMiddleware<State, Action>]
    let reducers: [AnyReducer<State, Action>]
    let resolvers: [AnyResolver<State, Action>]
    let onLog: ((Log) -> Void)?

    private var dispatchProcess: (@MainActor (State.ReadOnly, Action) -> Void)?

    private var task: Task<Void, Never>?
    weak var store: Store?
    private var state: State { store!._state }

    // MARK: - Init

    init(
      middlewares: [AnyMiddleware<State, Action>],
      resolvers: [AnyResolver<State, Action>],
      reducers: [AnyReducer<State, Action>],
      onLog: ((Log) -> Void)? = nil
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

    @discardableResult
    nonisolated func dispatch(
      maxDispatchable limit: UInt = 0,
      _ action: Action,
      completion: (@Sendable (State.ReadOnly) -> Void)? = nil
    ) -> Bool {
      dispatcher.tryEnqueue(id: action.id, limit: limit, (action: action, completion: completion))
    }

    // MARK: - Pipeline

    private func buildDispatchProcess() -> @MainActor (State.ReadOnly, Action) -> Void {
      let middlewares = self.middlewares
      let reducers = self.reducers
      let resolvers = self.resolvers
      let onLog = self.onLog

      return { [unowned self] readOnly, action in

        // 1. Reduce: applies all reducers in forward order.
        let reduce: Reduce = { [unowned self] action in
          MainActor.assumeIsolated {
            let currentState = self.state
            for reducer in reducers {
              let complete: Complete
              if let onLog {
                let start = ContinuousClock.now
                complete = { succeeded in
                  onLog(.reducer(reducer.id, action, ContinuousClock.now - start, succeeded))
                }
              } else {
                complete = { _ in }
              }
              let context = ReducerContext<State, Action>(
                state: currentState,
                action: action,
                complete: complete
              )
              reducer.reduce(context)
            }
          }
        }

        // 2. Resolve chain: built via fold, runs in user-supplied order.
        let resolveChain: ResolveChain = { [unowned self] error, action, origin in
          let seed: ResolveNext = { _, _ in }
          let chain = resolvers.reduce(seed) { next, resolver in
            { [unowned self] error, action in
              let complete: Complete
              if let onLog {
                let start = ContinuousClock.now
                complete = { succeeded in
                  onLog(.resolver(resolver.id, action, ContinuousClock.now - start, succeeded, error))
                }
              } else {
                complete = { _ in }
              }
              let context = ResolverContext<State, Action>(
                state: readOnly,
                action: action,
                error: error,
                origin: origin,
                dispatch: { [unowned self] limit, actions in
                  actions.forEach { self.dispatch(maxDispatchable: limit, $0) }
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
        let middlewareChain = middlewares.reduce(reduce) { next, middleware in
          { [unowned self] action in
            let middlewareResolve: Resolve = { error in
              resolveChain(error, action, .middleware(middleware.id))
            }
            let middlewareDispatch: Dispatch = { [unowned self] limit, actions in
              actions.forEach { self.dispatch(maxDispatchable: limit, $0) }
            }
            let complete: MiddlewareComplete
            if let onLog {
              let start = ContinuousClock.now
              complete = { result in
                onLog(.middleware(middleware.id, action, ContinuousClock.now - start, result))
              }
            } else {
              complete = { _ in }
            }
            let context = MiddlewareContext<State, Action>(
              action: action,
              dispatch: middlewareDispatch,
              resolve: middlewareResolve,
              task: { body in
                Task {
                  do {
                    try await body(readOnly)
                  } catch {
                    middlewareResolve(error)
                  }
                }
              },
              complete: complete,
              _next: next
            )
            do {
              try middleware.run(context)
            } catch {
              context.complete(.failure(error))
              middlewareResolve(error)
            }
          }
        }

        middlewareChain(action)
      }
    }
  }
}
