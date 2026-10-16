/// Shared results/leaderboard presentation. No dependencies or changes to measured time.
enum GameDurationFormatter {
  /// Floors completed seconds after clamping negatives to zero. Minutes never wrap to hours.
  /// Non-finite input displays zero; finite values beyond Int's range saturate safely.
  static func displayString(for elapsedTime: Double) -> String {
    let total = wholeSeconds(elapsedTime)
    return padded(total / 60) + ":" + padded(total % 60)
  }

  /// Natural speech for the same completed duration; omits zero units except at zero duration.
  static func spokenString(for elapsedTime: Double) -> String {
    let total = wholeSeconds(elapsedTime)
    let minutes = total / 60
    let seconds = total % 60
    let minuteText = "\(minutes) \(minutes == 1 ? "minute" : "minutes")"
    let secondText = "\(seconds) \(seconds == 1 ? "second" : "seconds")"
    if minutes == 0 { return secondText }
    if seconds == 0 { return minuteText }
    return minuteText + " " + secondText
  }

  private static func wholeSeconds(_ elapsedTime: Double) -> Int {
    guard elapsedTime.isFinite, elapsedTime > 0 else { return 0 }
    let completed = elapsedTime.rounded(.down)
    return completed >= Double(Int.max) ? Int.max : Int(completed)
  }

  private static func padded(_ value: Int) -> String {
    value < 10 ? "0\(value)" : String(value)
  }
}
