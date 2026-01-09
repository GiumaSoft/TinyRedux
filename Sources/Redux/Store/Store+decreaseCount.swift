// swift-tools-version: 6.0


import Foundation


extension Store {
  /// Updates the buffered count for a processed action, removing its tracking entry when the count
  /// reaches zero to keep buffer limits accurate and dictionaries compact during long dispatch
  /// sessions safely. Decrements the buffered count for an action after processing.
  func decreaseCount(for action: A) {
    guard let count = bufferedActionCount[action] else { return }
    if count <= 1 {
      bufferedActionCount.removeValue(forKey: action)
    } else {
      bufferedActionCount[action] = count - 1
    }
  }
}
