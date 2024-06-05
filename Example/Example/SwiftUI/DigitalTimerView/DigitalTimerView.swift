//


import SwiftUI
import TinyRedux


struct DigitalTimerView: View {
  // We get subStore from environment injected at ExampleApp.
  @EnvironmentObject private var store: SubStore<AppState, AppActions, TimerState, TimerActions>

  var body: some View {
    Button {
      // Start or stop timer
      store.dispatch( store.timerIsRunning ? .stopTimer : .startTimer)
    } label: {
      Circle()
        .overlay(
          // Display timeCount as timer format
          Text(store.timeCount.timeFormatted)
            .font(.title)
            .foregroundStyle(.white)
        )
    }
    .buttonStyle(.plain)
  }
}


#Preview {
  DigitalTimerView()
    .environmentObject(
      ExampleApp.timerStore
    )
    .padding()
}
