// swift-tools-version: 6.2


extension Duration {
  func fmt() -> String {
    let ms = UInt64(components.seconds * 1_000)
       + UInt64(components.attoseconds / 1_000_000_000_000_000)
    switch ms {
    case 0..<5_000:
      return "\(ms)ms"
    case 5_000..<60_000:
      return "\(ms / 1_000)s"
    case 60_000..<3_600_000:
      return "\(ms / 60_000)m"
    default:
      let h = ms / 3_600_000
      let m = (ms / 60_000) % 60
      return m == 0 ? "\(h)h" : "\(h)h\(m)m"
    }
  }
}
