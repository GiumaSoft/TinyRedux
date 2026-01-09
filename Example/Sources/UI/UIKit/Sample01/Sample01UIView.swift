//


import UIKit
import SwiftUI


extension UIKitSample {
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
  UIKitSample.Sample01View()
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
}
