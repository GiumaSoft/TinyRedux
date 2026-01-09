//


import Foundation
import Logging


extension LogSource {
  
  struct Handler: LogHandler,
                  Sendable {
    
    let label: String
    let logStream: LogSource
    var logLevel: Logger.Level
    var metadata: Logger.Metadata
    
    init(label: String, logLevel: Logger.Level = .trace, logStream: LogSource) {
      self.label = label
      self.logLevel = logLevel
      self.logStream = logStream
      self.metadata = [:]
    }
    
    subscript(metadataKey key: String) -> Logger.Metadata.Value? {
      get { metadata[key] }
      set { metadata[key] = newValue }
    }
    
    func log(event: LogEvent) {
      let entry = LogSource.Entry(
        date: .now,
        label: label,
        level: event.level,
        message: event.message,
        metadata: event.metadata,
        source: event.source,
        file: event.file,
        function: event.function,
        line: event.line
      )

      logStream.enqueue(entry)
    }
  }
}
