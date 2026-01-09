//


import UIKit


final class Sample01TableViewCell: UITableViewCell {
  
  @IBOutlet weak var label: UILabel!
  
  override func prepareForReuse() {
    label.text = nil
  }
}
