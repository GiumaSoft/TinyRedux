//


import Combine
import Observation
import UIKit


final class Sample04UIViewController: UIViewController {
  
  @IBOutlet private weak var tableView: UITableView!
  
  @Global(\.mainStore) private var store
  
  let disclaimer = "This sample view demonstrate a how to integrate a Redux flow in a SwiftUI View dispatching actions that add or remove items from the List view in a synchronous way."
  

  override func viewDidLoad() {
    super.viewDidLoad()
    tableView.register(
      UINib(nibName: "Sample04TableViewCell", bundle: Bundle(for: Sample04TableViewCell.self)),
      forCellReuseIdentifier: "Sample04TableViewCell"
    )
    tableView.reloadData()
    viewStateObserve()
  }
  
  @IBAction private func addDate(_ sender: UIButton) {
    store.dispatch(.insertDate)
  }
  
  @IBAction private func removeDate(_ sender: UIButton) {
    store.dispatch(.removeDate)
  }
  
  private func viewStateObserve() {
    withObservationTracking {
      _ = store.dates
    } onChange: {
      Task { @MainActor [weak self] in
        guard let self else { return }
        tableView.reloadData()
        viewStateObserve()
      }
    }
  }
}

extension Sample04UIViewController: UITableViewDelegate {
  
}

extension Sample04UIViewController: UITableViewDataSource {
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    store.dates.count
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "Sample04TableViewCell", for: indexPath)
    
    if let cell = cell as? Sample04TableViewCell {
      cell.label.text = store.dates[indexPath.row].formatted(date: .abbreviated, time: .standard)
    }
    
    return cell
  }
}
