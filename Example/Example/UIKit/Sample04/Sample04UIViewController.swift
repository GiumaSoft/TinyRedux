//


import UIKit


final class Sample04UIViewController: UIViewController {
  
  @IBOutlet private weak var tableView: UITableView!
  
  private var store = ExampleApp.sample01Store
  
  let disclaimer = "This sample view demonstrate a how to integrate a Redux flow in a SwiftUI View dispatching actions that add or remove items from the List view in a synchronous way."
  

  override func viewDidLoad() {
    super.viewDidLoad()
    tableView.register(UINib(nibName: "Sample04TableViewCell", bundle: nil), forCellReuseIdentifier: "Sample04TableViewCell")
  }
  
  @IBAction private func addDate(_ sender: UIButton) {
    store.dispatch(.insertDate)
    tableView.reloadData()
  }
  
  @IBAction private func removeDate(_ sender: UIButton) {
    store.dispatch(.removeDate)
    tableView.reloadData()
  }
}

extension Sample04UIViewController: UITableViewDelegate {
  
}

extension Sample04UIViewController: UITableViewDataSource {
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    store.count
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "Sample04TableViewCell", for: indexPath)
    
    if let cell = cell as? Sample04TableViewCell {
      cell.label.text = store[indexPath.row].formatted(date: .abbreviated, time: .standard)
    }
    
    return cell
  }
}