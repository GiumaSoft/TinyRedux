//


import Foundation
import SwiftUI
import TinyRedux


extension Sample.SwiftUI {
  struct Sample02View: View {
    @Global(\.mainStore) private var store
    
    let disclaimer = "This sample view demonstrate a how to integrate a Redux flow in a SwiftUI View dispatching actions that increase or decrease counter in a synchronous way. Additionally tapping on Timer start or stop an asynchronous automatic counter increment."
  }
}

extension Sample.SwiftUI.Sample02View {

  var body: some View {
    VStack {
      Spacer()
      _counter_
      Spacer()
      _disclaimer_
      Spacer()
      _commands_
    }
    .onDisappear {
      if store.timerIsRunning {
        store.dispatch(.stopAutoCounter)
      }
    }
  }
  
  @ViewBuilder private var _counter_: some View {
    Button {
      // Start or stop timer
      store.dispatch(store.timerIsRunning ? .stopAutoCounter : .startAutoCounter)
    } label: {
      Circle()
        .fill(.foreground)
        .overlay(
          // Display timeCount as timer format
          Text(store.timeCount.timeFormatted)
            .font(
              .system(
                size: 56,
                weight: .medium,
                design: .rounded
              )
            )
            .foregroundStyle(.background)
        )
    }
    .buttonStyle(.plain)
  }
  
  @ViewBuilder private var _disclaimer_: some View {
    Text(disclaimer)
      .multilineTextAlignment(.center)
      .font(.subheadline)
      .fontWeight(.bold)
      .padding()
  }

  @ViewBuilder private var _commands_: some View {
    HStack {
      _increaseCounter_
      _decreaseCounter_
    }
    .aspectRatio(2.0, contentMode: .fit)
  }
  
  @ViewBuilder private var _increaseCounter_: some View {
    Button {
      store.dispatch(.increase)
    } label: {
      Text("Increase counter")
        .padding()
        .background(
          RoundedRectangle(cornerRadius: 16)
            .stroke(lineWidth: 3)
        )
    }
  }
  
  @ViewBuilder private var _decreaseCounter_: some View {
    Button {
      store.dispatch(.decrease)
    } label: {
      Text("Decrease counter")
        .padding()
        .background(
          RoundedRectangle(cornerRadius: 16)
            .stroke(lineWidth: 3)
        )
    }
  }
}


#Preview {
  Sample.SwiftUI.Sample02View()
    .padding()
}
