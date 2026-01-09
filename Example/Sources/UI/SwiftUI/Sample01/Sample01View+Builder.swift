//


import SwiftUI


extension SwiftUISample.Sample01View {

  @ViewBuilder
  var _main_: some View {
    VStack(spacing: 20) {
      _cart_
      _total_
      Spacer()
      _catalog_
    }
  }

  @ViewBuilder
  var _cart_: some View {
    List {
      ForEach(entries) { entry in
        HStack {
          Text(entry.name)
          Spacer()
          Text(entry.price, format: .currency(code: "EUR"))
        }
      }
      .onDelete { indices in
        store.dispatch(.removeProducts(indices))
      }
    }
    .scrollContentBackground(.hidden)
  }

  @ViewBuilder
  var _total_: some View {
    HStack {
      Text("Total")
        .fontWeight(.bold)
      Spacer()
      Text(total, format: .currency(code: "EUR"))
        .fontWeight(.bold)
    }
    .padding(.horizontal)
  }

  @ViewBuilder
  var _catalog_: some View {
    HStack(spacing: 12) {
      ForEach(Product.catalog) { product in
        Button(product.name) {
          store.dispatch(.addProduct(product))
        }
      }
    }
    .buttonStyle(.borderedProminent)
  }
}

#Preview {
  SwiftUISample.Sample01View()
}
