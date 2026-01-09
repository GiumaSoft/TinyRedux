//


import UIKit
import SwiftUI


extension Sample.UIKit {
  struct Sample01View: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
      Sample01UIViewController(
        nibName: "Sample01UIViewController",
        bundle: Bundle(for: Sample01UIViewController.self)
      )
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
      
    }
  }
}


#Preview {
  Sample.UIKit.Sample01View()
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
}
