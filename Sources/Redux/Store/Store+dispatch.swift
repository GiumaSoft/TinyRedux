// swift-tools-version: 6.0


import Foundation


extension Store {
  /// Queues a single action with an optional per-action limit, enqueues it into the buffer, then
  /// starts the dispatcher to process actions sequentially on the MainActor in order for this
  /// dispatch. Enqueues a single action for processing.
  /// - Parameters:
  ///   - limit: Maximum buffered instances of the same action; 0 means unlimited.
  ///   - action: The action to dispatch.
  public func dispatch(maxDispatchable limit: UInt = 0, _ action: A) {
    _ = enqueue(
      .init(action: action, completion: nil),
      limit: limit
    )
    runDispatcher()
  }
  
  /// Queues multiple actions in order with the same limit, enqueues them into the buffer, then runs
  /// the dispatcher to process the batch sequentially on the MainActor for consistent results
  /// always. Enqueues multiple actions for processing.
  /// - Parameters:
  ///   - limit: Maximum buffered instances of the same action; 0 means unlimited.
  ///   - actions: The actions to dispatch.
  public func dispatch(maxDispatchable limit: UInt = 0, _ actions: A...) {
    _ = enqueue(
      contentsOf: actions.map { .init(action: $0, completion: nil) },
      limit: limit
    )
    runDispatcher()
  }

  public func dispatch(
    maxDispatchable limit: UInt = 0,
    _ action: A,
    completion: @escaping @MainActor (Result<S.ReadOnly, ReduxError>) -> Void
  ) {
    let enqueuedAction = EnqueuedAction(action: action, completion: completion)

    switch enqueue(enqueuedAction, limit: limit) {
    case .success:
      runDispatcher()
    case .failure(let error):
      completion(.failure(error))
    }
  }
}
