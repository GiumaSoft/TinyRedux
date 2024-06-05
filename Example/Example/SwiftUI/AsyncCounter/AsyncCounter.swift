//


import Foundation
import SwiftUI
import TinyRedux


struct AsyncCounter: View {
  @EnvironmentObject private var store: SubStore<AppState, AppActions, CounterState, CounterActions>
  
  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text("Async counter increment test")
        .font(.subheadline)
        .fontWeight(.bold)
      
      HStack(spacing: 60) {
        _plusButton_
        _minusButton_
        Spacer()
        Text(store.counter.description)
          .font(.title)
      }
      .padding()
    }
  }
  
  @ViewBuilder private var _plusButton_: some View {
    Button {
      // Add date item to the list
      store.dispatch(.increaseCounter)
    } label: {
      Image(systemName: "plus.circle.fill")
        .resizable()
        .tint(Color.black)
        .frame(width: 40, height: 40)
    }
    .buttonStyle(.plain)
  }
  
  @ViewBuilder private var _minusButton_: some View {
    Button {
      // Remove last inserted date
      store.dispatch(.decreaseCounter)
    } label: {
      Image(systemName: "minus.circle.fill")
        .resizable()
        .tint(Color.black)
        .frame(width: 40, height: 40)
    }
    .buttonStyle(.plain)
  }
}


#Preview {
  AsyncCounter()
    .padding()
    .environmentObject(
      ExampleApp.counterStore
    )
}
