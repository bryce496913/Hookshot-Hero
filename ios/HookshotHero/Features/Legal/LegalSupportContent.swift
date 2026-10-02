import Foundation

/// The single configuration point for public legal and support destinations.
/// Leave these values nil until the project's owner supplies verified production URLs.
enum LegalSupportLinks {
  static let privacyPolicyURL: URL? = nil
  static let supportURL: URL? = nil
}

enum AppVersionInformation {
  static func displayText(bundle: Bundle = .main) -> String {
    let version =
      bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
      ?? "Unknown"
    let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
    return "Version \(version) (\(build))"
  }
}

struct PolicySection: Identifiable, Equatable {
  let title: String
  let body: String
  var id: String { title }
}

enum PrivacyPolicyContent {
  static let effectiveDate = "October 2, 2026"
  static let introduction =
    "This policy describes how the current iOS version of Hookshot Hero handles information."

  static let sections = [
    PolicySection(
      title: "Information collection",
      body:
        "Hookshot Hero does not ask for your name, email address, account, location, photos, contacts, or other personal information. The app does not include advertising, analytics, tracking, or crash-reporting services."
    ),
    PolicySection(
      title: "Information stored on your device",
      body:
        "The app stores gameplay progress, including scores, completed levels and missions, and unlocked content, in its application storage. It stores gameplay preferences, including Reduced Motion, Control Hints, and Control Layout, in local settings. This information is used only to restore your progress and preferences."
    ),
    PolicySection(
      title: "Information leaving your device",
      body:
        "The current app has no networking, account, upload, or cloud-persistence feature. It does not transmit gameplay progress, settings, or personal information to the developer or a third party."
    ),
    PolicySection(
      title: "Third-party services",
      body:
        "The current app target contains no third-party frameworks or services. It uses Apple system frameworks to provide the app and its gameplay."
    ),
    PolicySection(
      title: "Retention and deletion",
      body:
        "Progress and settings remain locally on your device while the app is installed. You can delete that locally stored information by deleting the app. The current app does not provide an account or remote record for the developer to retrieve or delete."
    ),
    PolicySection(
      title: "Changes to this policy",
      body:
        "If the app's data practices change, this policy will be updated to describe the new practices and its effective date will be revised."
    ),
    PolicySection(
      title: "Support and contact",
      body:
        "Open Support from Settings for troubleshooting, version information, and the currently configured way to contact support. A verified public support destination has not yet been configured in this build."
    ),
  ]
}
