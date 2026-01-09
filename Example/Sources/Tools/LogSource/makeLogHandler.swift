//


import Logging


func makeLogHandler(label: String, logSource: LogSource) -> MultiplexLogHandler {
  MultiplexLogHandler([
    LogSource.Handler(label: label, logStream: logSource),
    StreamLogHandler.standardOutput(label: label)
  ])
}
