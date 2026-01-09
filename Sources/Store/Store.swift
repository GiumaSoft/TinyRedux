// swift-tools-version: 6.2


import SwiftUI


///
public typealias SendableError = any Error & Sendable


/// Store
/// 
/// Central hub that holds state, reducers, middlewares, and resolvers.
@MainActor
@Observable
@dynamicMemberLookup
public final class Store<State, Action> where State: ReduxState, Action: ReduxAction {
  private typealias Dispatch = @Sendable (UInt, Action...) -> Void
  private typealias Reduce = @Sendable (Action) -> Void
  private typealias Resolve = @Sendable (SendableError) -> Void
  private typealias ResolveChain = @Sendable (SendableError, Action, ReduxOrigin) -> Void
  private typealias ResolveNext = @Sendable (SendableError, Action) -> Void
  private typealias Complete = @Sendable (Bool) -> Void
  private typealias MiddlewareComplete = @Sendable (Result<Bool, Error>) -> Void

  internal let middlewares: [AnyMiddleware<State, Action>]
  internal let resolvers: [AnyResolver<State, Action>]
  internal let reducers: [AnyReducer<State, Action>]
  internal let onLog: (@Sendable (Log) -> Void)?
  internal var state: State

  private let actionCounter = ActionCounter()
  private let dispatcher: Dispatcher<Action>
  private var dispatchProcess: ((State.ReadOnly, Action) -> Void)!
  private var worker: Task<Void, Never>?

  public init(
    initialState: State,
    middlewares: [AnyMiddleware<State, Action>],
    resolvers: [AnyResolver<State, Action>],
    reducers: [AnyReducer<State, Action>],
    onLog: (@Sendable (Log) -> Void)? = nil
  ) {
    self.state = initialState
    self.middlewares = middlewares.reversed()
    self.resolvers = resolvers.reversed()
    self.reducers = reducers
    self.onLog = onLog
    self.dispatcher = Dispatcher()
    self.dispatchProcess = nil

    self.dispatchProcess = buildDispatchProcess()

    self.worker = Task { @MainActor [weak self] in
      guard let stream = self?.dispatcher.actions else { return }
      for await action in stream {
        guard let self else { return }
        self.onLog?(.store("dispatch .\(action)"))
        let readOnly = state.readOnly
        dispatchProcess(readOnly, action)
        actionCounter.decrease(id: action.id)
      }
    }
  }

  /// Accesses read-only state via dynamic member lookup.
  public subscript<Value>(dynamicMember keyPath: KeyPath<State.ReadOnly, Value>) -> Value {
    state.readOnly[keyPath: keyPath]
  }

  /// Publishes an action to the dispatcher for asynchronous processing.
  /// - Parameter maxDispatchable: Maximum number of buffered actions with the same `id`.
  ///   `0` (default) means unlimited.
  nonisolated
  public func dispatch(maxDispatchable: UInt = 0, _ action: Action) {
    guard actionCounter.tryEnqueue(id: action.id, limit: maxDispatchable) else { return }
    dispatcher.dispatch(action)
  }

  // MARK: - Pipeline

  private func buildDispatchProcess() -> (State.ReadOnly, Action) -> Void {
    let middlewares = self.middlewares
    let reducers = self.reducers
    let resolvers = self.resolvers
    let onLog = self.onLog

    return { [unowned self] readOnly, action in
      // 1. reduce: applies all reducers to state (sync, asserts MainActor)
      let reduce: Reduce = { [unowned self] action in
        MainActor.assumeIsolated {
          let currentState = self.state
          for reducer in reducers {
            let complete: Complete
            if let onLog {
              let start = ContinuousClock.now
              complete = { succeeded in
                let elapsed = ContinuousClock.now - start
                onLog(.reducer(reducer.id, action, elapsed, succeeded))
              }
            } else {
              complete = { _ in }
            }
            let context = ReducerContext(
              state: currentState,
              action: action,
              complete: complete
            )
            reducer.reduce(context)
          }
        }
      }

      // 2. resolve: chain of resolvers (synchronous)
      let resolveChain: ResolveChain = {
        [unowned self] error, action, origin in
        let seed: ResolveNext = { _, _ in }
        let chain = resolvers.reduce(seed) { next, resolver in
          { [unowned self] error, action in
            let complete: Complete
            if let onLog {
              let start = ContinuousClock.now
              complete = { succeeded in
                let elapsed = ContinuousClock.now - start
                onLog(.resolver(resolver.id, action, elapsed, succeeded, error))
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

      // 3. middleware chain (sync — async work goes through task launcher)
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
              let elapsed = ContinuousClock.now - start
              onLog(.middleware(middleware.id, action, elapsed, result))
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
