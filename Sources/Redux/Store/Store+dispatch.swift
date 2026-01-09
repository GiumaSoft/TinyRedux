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
    enqueue(action, limit: limit)
    runDispatcher()
  }
  
  /// Queues multiple actions in order with the same limit, enqueues them into the buffer, then runs
  /// the dispatcher to process the batch sequentially on the MainActor for consistent results
  /// always. Enqueues multiple actions for processing.
  /// - Parameters:
  ///   - limit: Maximum buffered instances of the same action; 0 means unlimited.
  ///   - actions: The actions to dispatch.
  public func dispatch(maxDispatchable limit: UInt = 0, _ actions: A...) {
    enqueue(contentsOf: actions, limit: limit)
    runDispatcher()
  }
}
