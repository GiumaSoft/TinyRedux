//


import Foundation
import Logging
import SwiftUI


extension LogSource {
  
  struct Entry: Identifiable {
    var id = UUID()
    let date: Date
    let label: String
    let level: Logger.Level
    let message: Logger.Message
    let metadata: Logger.Metadata?
    let source: String
    let file: String
    let function: String
    let line: UInt
    
    var flat: (Date, String, Logger.Level, Logger.Message, Logger.Metadata?, String) {
      (date, label, level, message, metadata, source)
    }
  }
}

extension LogSource.Entry: CustomStringConvertible {
  var description: String {
    var metaString = String()
    if let metadata {
      metaString = metadata.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: " ")
    }
    
    return "\(date.ISO8601Format(.iso8601)) \(level) \(label): \(metaString) [\(source)] \(message)"
  }
}
