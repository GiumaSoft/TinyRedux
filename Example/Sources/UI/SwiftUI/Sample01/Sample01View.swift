//


import SwiftUI
import TinyRedux

extension Sample.SwiftUI {
  struct Sample01View: View {
    @Global(\.mainStore) private var store
    
    let disclaimer = "This sample view demonstrate a how to integrate a Redux flow in a SwiftUI View dispatching actions that add or remove items from the List view in a synchronous way."
  }
}

extension Sample.SwiftUI.Sample01View {
  var body: some View {
    VStack(spacing: 24) {
      _dates_
      _disclaimer_
      _commands_
    }
  }
  
  @ViewBuilder private var _dates_: some View {
    List {
      ForEach(store.dates, id: \.self) { date in
        let formattedDate = date.formatted(
          date: .abbreviated,
          time: .complete
        )
        
        Text("\(formattedDate)")
      }
    }
    .listStyle(.plain)
  }
  
  @ViewBuilder private var _disclaimer_: some View {
    Text(disclaimer)
      .multilineTextAlignment(.center)
      .font(.subheadline)
      .fontWeight(.bold)
      .padding()
  }
  
  @ViewBuilder private var _commands_: some View {
    HStack(spacing: 20) {
      _addDateButton_
      _removeDateButton_
    }
  }
  
  @ViewBuilder private var _addDateButton_: some View {
    Button {
      store.dispatch(.insertDate)
    } label: {
      Text("Add")
        .padding()
        .background(
          RoundedRectangle(cornerRadius: 16)
            .stroke(lineWidth: 3)
        )
    }
  }
  
  @ViewBuilder private var _removeDateButton_: some View {
    Button {
      store.dispatch(.removeDate)
    } label: {
      Text("Remove")
        .padding()
        .background(
          RoundedRectangle(cornerRadius: 16)
            .stroke(lineWidth: 3)
        )
    }
  }
}


#Preview {
  Sample.SwiftUI.Sample01View()
}
