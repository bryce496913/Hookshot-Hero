import SwiftUI
import UIKit

/// Resolves actool's installed primary-icon resources, rather than treating
/// an AppIcon.appiconset as an ordinary runtime image set.
@MainActor enum PrimaryAppIcon {
  static let image: UIImage? = load()

  static func resourceNames(in info: [String: Any]) -> [String] {
    var names: [String] = []
    for key in ["CFBundleIcons", "CFBundleIcons~ipad"] {
      guard let icons = info[key] as? [String: Any],
            let primary = icons["CFBundlePrimaryIcon"] as? [String: Any] else { continue }
      names += primary["CFBundleIconFiles"] as? [String] ?? []
      if let name = primary["CFBundleIconName"] as? String { names.append(name) }
    }
    names += info["CFBundleIconFiles"] as? [String] ?? []
    var seen = Set<String>()
    return names.filter { !$0.isEmpty && seen.insert($0).inserted }
  }

  static func load(bundle: Bundle = .main) -> UIImage? {
    // UIImage resolves compiled names, file extensions and device scale suffixes.
    // Pick the largest representation actually available in the installed bundle.
    resourceNames(in: bundle.infoDictionary ?? [:])
      .compactMap { UIImage(named: $0, in: bundle, compatibleWith: nil) }
      .max { lhs, rhs in
        lhs.size.width * lhs.scale < rhs.size.width * rhs.scale
      }
  }
}

struct AppIconHeroView: View {
  let size: CGFloat
  private let image = PrimaryAppIcon.image

  var body: some View {
    Group {
      if let image {
        Image(uiImage: image).resizable().scaledToFit()
      } else {
        Image(systemName: "scope").resizable().scaledToFit()
          .padding(size * 0.22).foregroundStyle(AppTheme.Colors.highlight)
      }
    }
    .frame(width: size, height: size)
    // Scale-to-fit preserves the artwork; the rounded shape follows the icon edge.
    .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
        .stroke(AppTheme.Colors.accent.opacity(0.3), lineWidth: 1)
    }
    .shadow(color: AppTheme.Colors.accent.opacity(0.2), radius: 24, y: 8)
    .background {
      Circle().fill(AppTheme.Colors.accentSecondary.opacity(0.18)).blur(radius: 32)
    }
    .accessibilityHidden(true)
  }
}
