//


import UIKit
import SwiftUI


extension Sample.UIKit {
  struct Sample04View: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
      Sample04UIViewController(
        nibName: "Sample04UIViewController",
        bundle: Bundle(for: Sample04UIViewController.self)
      )
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
      
    }
  }
}


#Preview {
  Sample.UIKit.Sample04View()
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
}
