//


import UIKit


final class Sample04TableViewCell: UITableViewCell {
  
  @IBOutlet weak var label: UILabel!
  
  override func prepareForReuse() {
    label.text = nil
  }
}
