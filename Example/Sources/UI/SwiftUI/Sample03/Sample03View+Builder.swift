//


import SwiftUI


extension Sample.SwiftUI.Sample03View {
  
  @ViewBuilder
  var _main_: some View {
    VStack(spacing: 36) {
      Spacer()
      _unidirectionalBinding_
      Spacer()
      _disclaimer_
    }
  }

  @ViewBuilder var _unidirectionalBinding_: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text("Unidirectional binding test")
        .font(.subheadline)
        .fontWeight(.bold)
      
      TextField("", text: headerBind)
        .font(.title)
        .padding()
        .background(
          RoundedRectangle(cornerRadius: 16)
            .fill(Material.regular)
        )
    }
  }
  
  @ViewBuilder var _disclaimer_: some View {
    Text(disclaimer)
      .multilineTextAlignment(.center)
      .font(.subheadline)
      .fontWeight(.bold)
      .padding()
  }
}
