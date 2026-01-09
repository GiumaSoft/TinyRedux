//


import SwiftUI


extension Sample.SwiftUI.Sample02View {

  @ViewBuilder
  var _main_: some View {
    VStack {
      Spacer()
      _counter_
      Spacer()
      _disclaimer_
      Spacer()
      _commands_
    }
    .onDisappear {
      if timerIsRunning {
        store.dispatch(.stopAutoCounter)
      }
    }
  }
  
  @ViewBuilder var _counter_: some View {
    Button {
      // Start or stop timer
      store.dispatch(timerIsRunning ? .stopAutoCounter : .startAutoCounter)
    } label: {
      Circle()
        .fill(.foreground)
        .overlay(
          // Display timeCount as timer format
          Text(timeFormatted)
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
  
  @ViewBuilder var _disclaimer_: some View {
    Text(disclaimer)
      .multilineTextAlignment(.center)
      .font(.subheadline)
      .fontWeight(.bold)
      .padding()
  }

  @ViewBuilder var _commands_: some View {
    HStack {
      _increaseCounter_
      _decreaseCounter_
    }
    .aspectRatio(2.0, contentMode: .fit)
  }
  
  @ViewBuilder var _increaseCounter_: some View {
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
  
  @ViewBuilder var _decreaseCounter_: some View {
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
