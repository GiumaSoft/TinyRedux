//


import SwiftUI


/// Reusable log viewer that reads LogSource from the environment.
struct LogsWindow: View {
  
  var body: some View {
    if entries.count > 0 {
      List {
        ForEach(entries) { entry in
          Text(entry.description)
            .font(.caption)
            .fontWeight(.light)
            .fontDesign(.monospaced)
            .listRowBackground(Color.clear)
        }
      }
      .scrollContentBackground(.hidden)
    } else {
      ContentUnavailableView(
        "No logs yet",
        systemImage: "doc.plaintext",
        description: Text("Log messages will appear here.")
      )
    }
  }
  
  var entries: [LogSource.Entry] {
    logSource.entries.sorted { $0.date > $1.date }
  }
}
