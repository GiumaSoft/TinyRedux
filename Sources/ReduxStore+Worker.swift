//


import Foundation


extension ReduxStore {

  /// Worker
  ///
  /// Owns the live ``ReduxState`` and the reducer/middleware/resolver chains, and runs the
  /// dispatch loop: a main-actor `Task` drains the ``Dispatcher`` stream and processes each
  /// action through the pipeline — MIDDLEWARE (intercept + effects) → REDUCER, with the
  /// RESOLVER as the error branch and a State→Action SUBSCRIPTION registry. `deinit`
  /// finishes the dispatcher so the loop ends.
  final class Worker: Sendable
  {

    @MainActor
    let state: S

    let reducers: [AnyReduxReducer<S, A>]

    /// Action interceptors, run BEFORE the reducers (Redux `applyMiddleware`).
    let middlewares: [AnyReduxMiddleware<S, A>]

    /// Error handlers, run when a middleware/effect raises (throw / `.exit(.resolve)`).
    let resolvers: [AnyReduxResolver<S, A>]

    let dispatcher: Dispatcher

    /// Optional structured-log sink. `@Sendable`; thread-safety is the handler's.
    let onLog: ReduxLogHandler<S, A>?

    let options: ReduxStoreOptions

    @MainActor
    private var task: Task<Void, Never>?
    
    @MainActor
    private var childTasks: [UUID: Task<Void, Never>]

    /// State→Action subscriptions, keyed by id (no generation; lifecycle by id).
    @MainActor
    private var subscriptions: [String: ReduxSubscription<S, A>] = [:]

    /// Active snapshot streams (State→Data feeds). Finished eagerly by the store's `deinit`
    /// via ``finishAllStreams()`` (a separate `@MainActor` object → reached via a main-actor
    /// hop, not from the nonisolated `Worker.deinit`).
    @MainActor
    let streams = Streams()

    /// Single shared JSON encoder for ALL snapshot encoding (single-shot terminal + every
    /// stream frame). Safe: encoding only ever happens on the main actor (no concurrent
    /// `.encode()`); one instance, one config, no per-call/per-entry allocation.
    @MainActor
    let encoder = JSONEncoder()

    // Backpressure DIAGNOSTICS state (main-actor → no lock). Per `action.id`:
    // sliding window of recent reduce timestamps + last-warned time (anti-spam).
    @MainActor
    private var pressureHits: [String: [ContinuousClock.Instant]] = [:]
    @MainActor
    private var pressureLastWarned: [String: ContinuousClock.Instant] = [:]

    init( initialState state: S,
          reducers: [AnyReduxReducer<S, A>],
          middlewares: [AnyReduxMiddleware<S, A>] = [],
          resolvers: [AnyReduxResolver<S, A>] = [],
          options: ReduxStoreOptions = .init(),
          onLog: ReduxLogHandler<S, A>? = nil )
    {
      self.state = state
      self.reducers = reducers
      self.middlewares = middlewares
      self.resolvers = resolvers
      self.options = options
      self.onLog = onLog
      self.dispatcher = Dispatcher()
      self.childTasks = [:]

      let events = dispatcher.events
      self.task = Task { @MainActor [weak self] in
        for await event in events
        {
          guard let self else { return }
          runProcess(event)
        }
      }
    }

    deinit {
      dispatcher.finish()
      for task in childTasks.values { task.cancel() }
    }

    /// Enqueues an action for asynchronous processing. Thread-safe, any context.
    @discardableResult
    nonisolated
    func dispatch(_ action: A, rate: ReduxDispatchRateLimit = .none) -> Result<Void, ReduxError>
    {
      let result = dispatcher.tryEnqueue(action, rate: rate)
      if case .failure(let error) = result
      {
        onLog?(.store("discarded action '\(action.id)': \(error)"))
      }
      return result
    }

    /// Enqueues an action carrying a single-shot ``ReduxSnapshotRequest`` (always `.none` rate).
    /// On enqueue rejection the continuation is resolved immediately so the caller never
    /// hangs. Thread-safe, any context.
    nonisolated
    func dispatch(_ action: A, snapshot request: ReduxSnapshotRequest<S>)
    {
      let result = dispatcher.tryEnqueue(action, rate: .none, onTerminal: request)
      if case .failure(let error) = result
      {
        request.continuation.resume(returning: .failure(error))
        onLog?(.snapshot(.failed(action: action, error: error)))
      }
    }

    // MARK: - Pipeline

    /// Processes one action on the main actor: MIDDLEWARE chain → REDUCER, threading the
    /// single-shot terminal (built from the event's optional ``ReduxSnapshotRequest``).
    @MainActor
    private func runProcess(_ event: TaggedActionEvent)
    {
      trackPressure(event.action.id)
      runMiddleware(event.action, makeTerminal(event.action, event.onTerminal))
      dispatcher.consume(id: event.action.id, counted: event.counted)
    }

    /// Builds the once-only terminal callback from a single-shot request (`nil` if none).
    /// `.success(state)` → encode with the shared `encoder` and resume `.success(Data)` (or
    /// `.failure` if encoding throws); `.failure(error)` → resume `.failure`. Resolving the
    /// continuation never needs `self`; only logging does.
    @MainActor
    private func makeTerminal(_ action: A, _ request: ReduxSnapshotRequest<S>?) -> ReduxSnapshotTerminal<S>?
    {
      guard let request else { return nil }
      return { [weak self] result in
        switch result
        {
          case .success(let readOnly):
            guard let self else { request.continuation.resume(returning: .failure(ReduxError.cancelled)); return }
            let start = ContinuousClock.now
            do
            {
              let data = try request.capture(readOnly, self.encoder)
              request.continuation.resume(returning: .success(data))
              self.emit(.snapshot(.resolved(action: action, byteCount: data.count, duration: .now - start)))
            }
            catch
            {
              request.continuation.resume(returning: .failure(error))
              self.emit(.snapshot(.failed(action: action, error: error)))
            }
          case .failure(let error):
            request.continuation.resume(returning: .failure(error))
            self?.emit(.snapshot(.failed(action: action, error: error)))
        }
      }
    }

    /// Folds the middlewares (declaration order) into a chain seeded by the reducer stage.
    /// `terminal` (single-shot snapshot) is threaded to every settle point and fires once.
    @MainActor
    private func runMiddleware(_ action: A, _ terminal: ReduxSnapshotTerminal<S>?)
    {
      let dispatch: @Sendable (A) -> Void = { [weak self] a in self?.dispatch(a) }
      let seed: @MainActor (A) -> Void = { [weak self] a in self?.reduceChain(a, terminal) }

      guard !middlewares.isEmpty else { seed(action); return }

      let chain = middlewares.reversed().reduce(seed)
      { next, middleware in
        { [weak self] a in
          guard let self else { return }

          let context = ReduxMiddlewareContext(
            self.state,
            dispatch: dispatch,
            action: a,
            register: { [weak self] id, registeredBy, when, then in
              self?.registerSubscription(id: id, origin: middleware.id, registeredBy: registeredBy, when: when, then: then)
            },
            unregister: { [weak self] id in self?.unregisterSubscription(id) }
          )

          let start = ContinuousClock.now
          let exit: ReduxMiddlewareExit<S, A>
          do { exit = try middleware.run(context) }
          catch { self.resolveChain(error, a, origin: middleware.id, terminal); return }

          switch exit
          {
            case .next:
              self.emit(.middleware(id: middleware.id, action: a, duration: .now - start, exit: exit))
              next(a)
            case .defaultNext:
              next(a)                               // "not mine" → not logged
            case .nextAs(let newAction):
              self.emit(.middleware(id: middleware.id, action: a, duration: .now - start, exit: exit))
              next(newAction)
            case .exit(let target):
              self.emit(.middleware(id: middleware.id, action: a, duration: .now - start, exit: exit))
              switch target
              {
                case .reduce:                   self.reduceChain(a, terminal)
                case .reduceAs(let newAction):  self.reduceChain(newAction, terminal)
                case .resolve(let error):       self.resolveChain(error, a, origin: middleware.id, terminal)
                case .done:
                  terminal?(.success(self.state.readOnly))
                  
                  return
              }
            case .task(let body):
              self.runTask(body, a, origin: middleware.id)
              next(a)                               // fire-and-forget: chain continues (terminal flows through next)
            case .deferred(let handler):
              self.runDeferredTask(handler, next, a, origin: middleware.id, terminal)
          }
        }
      }

      chain(action)
    }

    /// Reducer stage: applies the reducers, evaluates the subscriptions, ticks the snapshot
    /// streams, then fires the single-shot `terminal` once on the settled projection.
    @MainActor
    private func reduceChain(_ action: A, _ terminal: ReduxSnapshotTerminal<S>? = nil)
    {
      runReducers(action)
      evaluateSubscriptions()
      evaluateStreams()
      terminal?(.success(state.readOnly))
    }

    /// Runs the reducer chain for a single action on the main actor.
    @MainActor
    private func runReducers(_ action: A)
    {
      for reducer in reducers
      {
        let context = ReduxReducerContext(state, action)
        let exit = measuring({ exit, duration in
          .reducer(id: reducer.id, action: action, duration: duration, exit: exit)
        }) {
          reducer.reduce(context)
        }
        switch exit
        {
          case .next, .defaultNext: continue
          case .done:               return
        }
      }
    }

    // MARK: - ReduxResolver (error branch)

    /// Folds the resolvers (declaration order), seeded by the default resolver (fail).
    @MainActor
    private func resolveChain(_ error: ReduxSendableError, _ action: A, origin: ReduxOrigin,
                             _ terminal: ReduxSnapshotTerminal<S>? = nil)
    {
      let fail: @MainActor (ReduxSendableError, A) -> Void = { [weak self] e, a in
        self?.emit(.resolver(id: "default", action: a, duration: .zero, exit: .exit(.fail(e)), error: e))
        terminal?(.failure(e))                  // unhandled → fail the single-shot
      }

      guard !resolvers.isEmpty else { fail(error, action); return }

      let chain = resolvers.reversed().reduce(fail)
      { next, resolver in
        { [weak self] e, a in
          guard let self else { return }

          let context = ReduxResolverContext(
            self.state,
            action: a,
            error: e,
            origin: origin,
            dispatch: { [weak self] newAction in self?.dispatch(newAction) }
          )

          let start = ContinuousClock.now
          let exit = resolver.run(context)
          switch exit
          {
            case .defaultNext:
              next(e, a)                            // pass to next resolver ("not mine")
            case .exit(let target):
              self.emit(.resolver(id: resolver.id, action: a, duration: .now - start, exit: exit, error: e))
              switch target
              {
                case .reduce:                  self.reduceChain(a, terminal)
                case .reduceAs(let newAction): self.reduceChain(newAction, terminal)
                case .fail(let resolved):      terminal?(.failure(resolved))
                
                  return   // terminal failure
                case .done:                    terminal?(.success(self.state.readOnly))
                
                  return   // done
              }
          }
        }
      }

      chain(error, action)
    }

    // MARK: - Async effects

    /// Fire-and-forget effect: runs off the synchronous chain (which already continued).
    /// Errors route to the resolver. The body runs on the main actor (reads `@MainActor`
    /// state; `await` points free the main actor for I/O).
    @MainActor
    private func runTask(_ body: @escaping ReduxTaskHandler<S>, _ action: A, origin: ReduxOrigin)
    {
      let id = UUID()
      let task = Task { @MainActor [weak self] in
                        defer { self?.childTasks[id] = nil }
                        guard let ro = self?.state.readOnly else { return }
                        do    { try await body(ro) }
                        catch { self?.resolveChain(error, action, origin: origin) }
                      }
      childTasks[id] = task
    }

    /// Suspending effect: awaits the handler, then RESUMES the chain per the resume exit.
    @MainActor
    private func runDeferredTask(_ handler: @escaping ReduxDeferredTaskHandler<S, A>,
                                 _ next: @escaping @MainActor (A) -> Void,
                                 _ action: A,
                                 origin: ReduxOrigin,
                                 _ terminal: ReduxSnapshotTerminal<S>?)
    {
      let id = UUID()
      let task = Task { @MainActor [weak self] in
        defer { self?.childTasks[id] = nil }
        guard let ro = self?.state.readOnly else { terminal?(.failure(ReduxError.cancelled)); return }
        do
        {
          let resume = try await handler(ro)
          guard let self else { terminal?(.failure(ReduxError.cancelled)); return }
          switch resume
          {
            case .next:                   next(action)              // terminal flows through the chain seed
            case .nextAs(let newAction):  next(newAction)
            case .exit(let target):
              switch target
              {
                case .reduce:                  self.reduceChain(action, terminal)
                case .reduceAs(let newAction): self.reduceChain(newAction, terminal)
                case .resolve(let error):      self.resolveChain(error, action, origin: origin, terminal)
                case .done:                    terminal?(.success(self.state.readOnly))
              }
          }
        }
        catch
        {
          guard let self else { terminal?(.failure(ReduxError.cancelled)); return }
          self.resolveChain(error, action, origin: origin, terminal)
        }
      }
      childTasks[id] = task
    }

    // MARK: - Subscriptions (State→Action)

    /// Registers a State→Action subscription (called by the middleware context).
    @MainActor
    private func registerSubscription(id: String,
                                      origin: String,
                                      registeredBy: A,
                                      when: @escaping ReduxSubscriptionPredicate<S>,
                                      then: @escaping ReduxSubscriptionHandler<S, A>)
    {
      let start = ContinuousClock.now
      subscriptions[id] = ReduxSubscription(id: id, origin: origin, registeredBy: registeredBy, when: when, then: then)
      emit(.subscription(.subscribed(origin: origin, id: id, registeredBy: registeredBy, duration: .now - start)))
    }

    /// Removes a subscription by id (called by the middleware context).
    @MainActor
    private func unregisterSubscription(_ id: String)
    {
      let start = ContinuousClock.now
      guard let removed = subscriptions.removeValue(forKey: id) else { return }
      emit(.subscription(.unsubscribed(origin: removed.origin, id: id, duration: .now - start)))
    }

    /// Evaluates every subscription against the current state and fires (dispatches) the
    /// matching reactions **once** — each fired subscription is REMOVED before its reaction
    /// is dispatched (fire-once on the `when` condition). Removing first means a re-entrant
    /// reduce cannot re-fire it and a predicate that stays true does not run away. Called
    /// after each reduce. A subscription may also be cancelled early by id (`unsubscribe`).
    @MainActor
    private func evaluateSubscriptions()
    {
      guard !subscriptions.isEmpty else { return }
      let readOnly = state.readOnly

      let fired = subscriptions.values.filter { $0.when(readOnly) }
      guard !fired.isEmpty else { return }

      // Remove all matches up-front, then dispatch — fire-once, re-entrancy-safe.
      for subscription in fired { subscriptions.removeValue(forKey: subscription.id) }

      for subscription in fired
      {
        let start = ContinuousClock.now
        let action = subscription.then(readOnly)
        emit(.subscription(.executed(origin: subscription.origin,
                                     id: subscription.id,
                                     registeredBy: subscription.registeredBy,
                                     duration: .now - start,
                                     trigger: action)))
        dispatch(action)
      }
    }

    // MARK: - Snapshot streams (State→Data)

    /// Registers a snapshot-stream entry and aligns its edge-trigger cursor to the current
    /// state: with `emitInitial` it emits the current state now (removing the entry if that
    /// first frame already exhausts it); otherwise it primes the cursor so only subsequent
    /// changes emit. A zero count bound finishes without registering (no frame).
    @MainActor
    func registerStream(_ entry: StreamEntry, action: A, emitInitial: Bool)
    {
      if let remaining = entry.remaining, remaining == 0 { entry.finish(); return }

      let readOnly = state.readOnly
      streams.register(entry)
      emit(.snapshot(.streamRegistered(id: entry.id, action: action, emitInitial: emitInitial)))

      guard emitInitial else { entry.prime(readOnly); return }
      if logTick(entry, entry.tick(readOnly, encoder: encoder)) { streams.unregister(id: entry.id) }
    }

    /// Ticks every active stream against the post-reduce state, logs per outcome, and
    /// removes exhausted entries. The SOLE periodic stream hook — state only changes at a
    /// reduce terminal. Zero-cost when no stream is registered.
    @MainActor
    private func evaluateStreams()
    {
      guard !streams.entries.isEmpty else { return }
      let readOnly = state.readOnly
      var finished: [String] = []
      for entry in streams.entries
      {
        if logTick(entry, entry.tick(readOnly, encoder: encoder)) { finished.append(entry.id) }
      }
      for id in finished { streams.unregister(id: id) }
    }

    /// Emits the log event for one ``TickOutcome`` and reports whether the entry is
    /// exhausted (so the caller removes it). Keeps `StreamEntry` free of `onLog`.
    @MainActor
    private func logTick(_ entry: StreamEntry, _ outcome: TickOutcome) -> Bool
    {
      switch outcome
      {
        case .unchanged:
          return false
        case .frame(let n):
          emit(.snapshot(.streamFrame(id: entry.id, byteCount: n)))
          return false
        case .encodeFailed(let error):
          emit(.snapshot(.streamEncodeFailed(id: entry.id, error: error)))
          return false
        case .finished(let n):
          emit(.snapshot(.streamFrame(id: entry.id, byteCount: n)))
          emit(.snapshot(.streamFinished(id: entry.id, reason: .limitReached)))
          return true
      }
    }

    /// Eagerly finishes every active snapshot stream (invoked by the store's `deinit` via a
    /// main-actor hop). Each consumer's `for await` ends, firing its `onTermination`.
    @MainActor
    func finishAllStreams()
    {
      for entry in streams.entries
      {
        emit(.snapshot(.streamFinished(id: entry.id, reason: .storeTerminated)))
      }
      streams.finishAll()
    }

    /// Emits a stream-finished log from the stream's own `dispatch` body (arming rejection /
    /// time bound / consumer cancel), where `emit` is not reachable. The caller logs only
    /// when it is the one that removed the entry (`unregister` returned `true`), so each
    /// stream is finished-logged exactly once across all termination sources.
    @MainActor
    func noteStreamFinished(id: String, reason: ReduxStreamFinishReason)
    {
      emit(.snapshot(.streamFinished(id: id, reason: reason)))
    }

    // MARK: - Logging (zero-cost when `onLog == nil`)

    /// Emits a log event. The `@autoclosure` is evaluated only when a handler exists.
    @MainActor
    @inline(__always)
    func emit(_ event: @autoclosure () -> ReduxLog<S, A>)
    {
      guard let onLog else { return }
      onLog(event())
    }

    /// Runs `body`, and ONLY if a handler exists reads the clock and emits the event
    /// built from the result + elapsed time. Hot path (no logger) pays nothing.
    @MainActor
    @inline(__always)
    func measuring<R>(_ make: (R, Duration) -> ReduxLog<S, A>,
                      _ body: () -> R) -> R
    {
      guard let onLog else { return body() }
      let start = ContinuousClock.now
      let result = body()
      onLog(make(result, .now - start))
      return result
    }

    // MARK: - Backpressure diagnostics (high-frequency detection; no drop)

    /// Records a reduced action's `id` in a sliding window and emits `.highFrequencyAction`
    /// when it exceeds the configured rate (anti-spam by cooldown). Only with a logger.
    @MainActor
    private func trackPressure(_ id: String)
    {
      guard onLog != nil else { return }

      let now = ContinuousClock.now
      var hits = pressureHits[id, default: []]
      hits.removeAll { now - $0 > options.pressureWindow }
      hits.append(now)
      pressureHits[id] = hits

      guard hits.count > options.pressureThreshold else { return }
      if let last = pressureLastWarned[id], now - last <= options.pressureCooldown
      {
        return
      }

      pressureLastWarned[id] = now
      emit(.highFrequencyAction(id: id, count: hits.count, window: options.pressureWindow))
    }
  }
}
