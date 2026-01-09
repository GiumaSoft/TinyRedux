//


import Foundation
import SwiftUI


struct ContentView: View {
  var body: some View {
    NavigationStack {
      List {
        Section {
          NavigationLink {
            SwiftUISample.Sample01View()
          } label: {
            _row("Sample01", subtitle: "Reducer")
          }

          NavigationLink {
            SwiftUISample.Sample02View()
          } label: {
            _row("Sample02", subtitle: "")
          }

          NavigationLink {
            SwiftUISample.Sample03View()
          } label: {
            _row("Sample03", subtitle: "")
          }

          NavigationLink {
            SwiftUISample.Sample04View()
          } label: {
            _row("Sample04", subtitle: "")
          }

          NavigationLink {
            SwiftUISample.Sample05View()
          } label: {
            _row("Sample05", subtitle: "")
          }

          NavigationLink {
            SwiftUISample.Sample06View()
          } label: {
            _row("Sample06", subtitle: "")
          }

          NavigationLink {
            SwiftUISample.Sample07View()
          } label: {
            _row("Sample07", subtitle: "")
          }

          NavigationLink {
            SwiftUISample.Sample08View()
          } label: {
            _row("Sample08", subtitle: "")
          }

          NavigationLink {
            SwiftUISample.Sample09View()
          } label: {
            _row("Sample09", subtitle: "")
          }

          NavigationLink {
            SwiftUISample.Sample10View()
          } label: {
            _row("Sample10", subtitle: "")
          }

          NavigationLink {
            SwiftUISample.Sample11View()
          } label: {
            _row("Sample11", subtitle: "")
          }

          NavigationLink {
            SwiftUISample.Sample12View()
          } label: {
            _row("Sample12", subtitle: "")
          }

          NavigationLink {
            SwiftUISample.Sample13View()
          } label: {
            _row("Sample13", subtitle: "")
          }

          NavigationLink {
            SwiftUISample.Sample14View()
          } label: {
            _row("Sample14", subtitle: "")
          }

          NavigationLink {
            SwiftUISample.Sample15View()
          } label: {
            _row("Sample15", subtitle: "")
          }

          NavigationLink {
            SwiftUISample.Sample16View()
          } label: {
            _row("Sample16", subtitle: "")
          }

          NavigationLink {
            SwiftUISample.Sample17View()
          } label: {
            _row("Sample17", subtitle: "")
          }

          NavigationLink {
            SwiftUISample.Sample18View()
          } label: {
            _row("Sample18", subtitle: "")
          }

          NavigationLink {
            SwiftUISample.Sample19View()
          } label: {
            _row("Sample19", subtitle: "")
          }

          NavigationLink {
            SwiftUISample.Sample20View()
          } label: {
            _row("Sample20", subtitle: "")
          }

          NavigationLink {
            SwiftUISample.Sample21View()
          } label: {
            _row("Sample21", subtitle: "")
          }
        } header: {
          Text("SwiftUI")
        }

        Section {
          NavigationLink {
            UIKitSample.Sample01View()
          } label: {
            _row("Sample01", subtitle: "Reducer (UIKit)")
          }
        } header: {
          Text("UIKit")
        }
      }
      .listStyle(.plain)
      .safeAreaPadding(.top)
    }
  }

  @ViewBuilder
  func _row(_ title: String, subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(title)
        .font(.body)

      Text(subtitle)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }
}



#Preview {
  ContentView()
    .padding()
}
