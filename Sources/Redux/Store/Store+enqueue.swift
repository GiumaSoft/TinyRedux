// swift-tools-version: 6.0


import Foundation


extension Store {
  /// Adds a single action to the buffer if under the limit, logs the enqueue, and increments the
  /// per-action count to enforce throttling for repeated actions during bursts and loops safely.
  /// Enqueues a single action and enforces the buffer limit.
  @discardableResult
  func enqueue(_ enqueuedAction: EnqueuedAction, limit: UInt) -> Result<EnqueuedAction, ReduxError> {
    let action = enqueuedAction.action

    if limit > 0 {
      let count = bufferedActionCount[action, default: 0]
      guard count < limit else {
        return .failure(.storeDropActionByQueueLimit(limit: limit))
      }
    }
    
    onLog?(.store("dispatch .\(action)"))
    
    actionBuffer.append(enqueuedAction)
    bufferedActionCount[action, default: 0] += 1
    return .success(enqueuedAction)
  }
  
  /// Adds multiple actions in order, applying the same limit to each and reusing single-action
  /// enqueue logic to preserve order, logging, and count tracking for batch dispatch operations and
  /// tests consistently. Enqueues a list of actions in order.
  func enqueue(contentsOf enqueuedActions: [EnqueuedAction], limit: UInt) -> [Result<EnqueuedAction, ReduxError>] {
    enqueuedActions.map { enqueue($0, limit: limit) }
  }
}
