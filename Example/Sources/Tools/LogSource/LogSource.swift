//


import DequeModule
import Logging
import SwiftUI


@MainActor
@Observable
final class LogSource {
  
  private(set) var entries: Deque<Entry>
  let maxEntries: Int
  
  nonisolated let continuation: AsyncStream<Entry>.Continuation
  private var consumeTask: Task<Void, Never>?
  
  init(label: String, logLevel: Logger.Level = .trace, maxEntries: Int = 500) {
    self.entries = []
    self.maxEntries = maxEntries
    
    let (stream, continuation) = AsyncStream<Entry>.makeStream(bufferingPolicy: .bufferingNewest(maxEntries))
    self.continuation = continuation
    
    self.consumeTask = Task { @MainActor [weak self] in
      for await entry in stream {
        guard let self, !Task.isCancelled else { return }
        entries.append(entry)
        if entries.count > maxEntries {
          entries.removeFirst()
        }
      }
    }
  }
  
  nonisolated func enqueue(_ entry: Entry) {
    continuation.yield(entry)
  }
  
  func clear() {
    entries.removeAll()
  }
  
  isolated
  deinit {
    continuation.finish()
    consumeTask?.cancel()
  }
}
