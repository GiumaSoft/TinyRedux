//


import SwiftUI


extension Sample.SwiftUI.Sample04View {
  
  @ViewBuilder
  var _main_: some View {
    VStack(spacing: 24) {
      Spacer()
      _status_
      _commands_
      Spacer()
      _disclaimer_
    }
    .alert(
      "Effect Error",
      isPresented: effectAlertPresentedBind
    ) {
      Button("OK", role: .cancel) { }
    } message: {
      Text(verbatim: "\(effectAlertMessage)")
    }
  }
  
  @ViewBuilder var _status_: some View {
    VStack(spacing: 12) {
      Text("runTask Demo")
        .font(.title2)
        .fontWeight(.bold)

      Text(effectMessage)
        .multilineTextAlignment(.center)
        .font(.subheadline)
        .padding()
        .frame(maxWidth: .infinity)
        .background(
          RoundedRectangle(cornerRadius: 16)
            .fill(Material.regular)
        )

      if effectIsRunning {
        ProgressView()
      }
    }
    .padding(.horizontal)
  }
  
  @ViewBuilder var _commands_: some View {
    VStack(spacing: 12) {
      _button(effectIsRunningStatus)
      _button("Run Failing Effect")
    }
    .padding(.horizontal)
  }

  @ViewBuilder
  var _disclaimer_: some View {
    Text(disclaimer)
      .multilineTextAlignment(.center)
      .font(.subheadline)
      .fontWeight(.bold)
      .padding()
  }
  
  @ViewBuilder
  func _button(_ title: String = "") -> some View {
    Button {
      dispatch(.runEffectDemoFailure)
    } label: {
      Text(title)
        .padding()
        .frame(maxWidth: .infinity)
        .foregroundStyle(buttonForeground)
        .background(
          RoundedRectangle(cornerRadius: 16)
        )
    }
    .buttonStyle(.plain)
    .disabled(effectIsRunning)
    .opacity(buttonOpacity)
  }
}
