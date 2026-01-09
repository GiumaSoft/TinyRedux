//

import SwiftUI
import TinyRedux

extension Sample.SwiftUI {
  struct Sample04View: View {
    @Global(\.mainStore) private var store

    let disclaimer = "This sample view demonstrates runTask by triggering an async task in middleware and updating state when it completes."
  }
}

extension Sample.SwiftUI.Sample04View {
  var body: some View {
    VStack(spacing: 24) {
      Spacer()
      _status_
      _commands_
      Spacer()
      _disclaimer_
    }
    .alert(
      "Effect Error",
      isPresented: store.bind(\.effectAlertPresented) {
        .setEffectAlertPresented($0)
      }
    ) {
      Button("OK", role: .cancel) {
        store.dispatch(.setEffectAlertPresented(false))
      }
    } message: {
      Text(store.effectAlertMessage.isEmpty ? "Unknown error." : store.effectAlertMessage)
    }
  }

  @ViewBuilder private var _status_: some View {
    VStack(spacing: 12) {
      Text("runTask Demo")
        .font(.title2)
        .fontWeight(.bold)

      Text(store.effectMessage)
        .multilineTextAlignment(.center)
        .font(.subheadline)
        .padding()
        .frame(maxWidth: .infinity)
        .background(
          RoundedRectangle(cornerRadius: 16)
            .fill(Material.regular)
        )

      if store.effectIsRunning {
        ProgressView()
      }
    }
    .padding(.horizontal)
  }

  @ViewBuilder private var _commands_: some View {
    VStack(spacing: 12) {
      Button {
        store.dispatch(.runEffectDemo)
      } label: {
        Text(store.effectIsRunning ? "Running..." : "Run Effect")
          .padding()
          .frame(maxWidth: .infinity)
          .background(
            RoundedRectangle(cornerRadius: 16)
              .stroke(lineWidth: 3)
          )
      }
      .buttonStyle(.plain)
      .disabled(store.effectIsRunning)
      .opacity(store.effectIsRunning ? 0.6 : 1.0)

      Button {
        store.dispatch(.runEffectDemoFailure)
      } label: {
        Text("Run Failing Effect")
          .padding()
          .frame(maxWidth: .infinity)
          .background(
            RoundedRectangle(cornerRadius: 16)
              .stroke(style: StrokeStyle(lineWidth: 3, dash: [6]))
          )
      }
      .buttonStyle(.plain)
      .disabled(store.effectIsRunning)
      .opacity(store.effectIsRunning ? 0.6 : 1.0)
    }
    .padding(.horizontal)
  }

  @ViewBuilder private var _disclaimer_: some View {
    Text(disclaimer)
      .multilineTextAlignment(.center)
      .font(.subheadline)
      .fontWeight(.bold)
      .padding()
  }
}


#Preview {
  Sample.SwiftUI.Sample04View()
    .padding()
}
