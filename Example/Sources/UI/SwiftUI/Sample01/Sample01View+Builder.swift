//


import SwiftUI


extension Sample.SwiftUI.Sample01View {
  
  @ViewBuilder
  var _main_: some View {
    VStack(spacing: 24) {
      _dates_
      _disclaimer_
      _commands_
    }
  }
  
  @ViewBuilder var _dates_: some View {
    List {
      ForEach(dates, id: \.self) { date in
        let formattedDate = date.formatted(
          date: .abbreviated,
          time: .complete
        )
        
        Text("\(formattedDate)")
      }
    }
    .listStyle(.plain)
  }
  
  @ViewBuilder var _disclaimer_: some View {
    Text(disclaimer)
      .multilineTextAlignment(.center)
      .font(.subheadline)
      .fontWeight(.bold)
      .padding()
  }
  
  @ViewBuilder var _commands_: some View {
    HStack(spacing: 20) {
      _addDateButton_
      _removeDateButton_
    }
  }
  
  @ViewBuilder var _addDateButton_: some View {
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
  
  @ViewBuilder var _removeDateButton_: some View {
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
