# App Store Submission Checklist

## Required metadata

- **Privacy Policy URL:** REQUIRED BEFORE SUBMISSION
- **Support URL:** REQUIRED BEFORE SUBMISSION
- **App Privacy answers:** MUST MATCH THE ACTUAL SOURCE AUDIT

No verified production privacy-policy URL, support URL, or support email was found in the repository during the October 2, 2026 audit. Add verified HTTPS destinations to `LegalSupportLinks`, publish the reviewed wording in `PRIVACY.md` at the privacy-policy destination, and enter both URLs manually in App Store Connect. This repository change does not configure App Store Connect.

## Public-site publication status

The project owner supplied the following intended Google Sites destinations on October 3, 2026:

- **Privacy Policy:** `https://sites.google.com/view/hoookshot-hero/privacy-policy`
- **Support:** `https://sites.google.com/view/hoookshot-hero/home`
- **Intended hosting mechanism:** Google Sites

These destinations could not be reached from the release-validation environment on October 3,
2026: its outbound proxy rejected both requests before an HTTP response was received. Search-based
validation also did not find an indexed copy of either page. Consequently, neither destination has
been accepted as verified production configuration, and `LegalSupportLinks` intentionally remains
unset. An operator with public internet access must verify a successful HTTPS response, the expected
page content, and anonymous access to both exact URLs before configuring them in the app.

## Native iOS source audit

The `HookshotHero` application target and its Xcode project configuration were reviewed, using the native Swift target rather than assumptions from the Java project.

| Area | Verified implementation |
| --- | --- |
| Networking | No networking API or networking feature is present. |
| Analytics | No analytics SDK or application analytics code is present. |
| Advertising | No advertising SDK or advertising feature is present. |
| Crash reporting | No crash-reporting SDK or service is present. Unified logging is local system logging, not a reporting service. |
| Accounts/login | No account, registration, or login system is present. |
| Location | No location API or location permission is present. |
| Tracking | No tracking API, tracking permission, or cross-app tracking is present. |
| User uploads | No user-generated content selection or upload flow is present. |
| Cloud persistence | No CloudKit, iCloud container, or other remote persistence is present. |
| Local persistence | Progression (score, completion, missions, unlocks) is stored as an app-support JSON file. Reduced Motion, Control Hints, and Control Layout settings are stored with `UserDefaults`. |
| Third-party frameworks | The app target has no linked framework binaries or Swift package dependencies. It imports Apple frameworks only. |

## Before submission

- Re-audit the shipping source and dependencies, then make App Privacy answers match that build.
- Reconcile any changed practice with both `PRIVACY.md` and `PrivacyPolicyContent`.
- Supply and verify the real public URLs; do not replace them with placeholder domains.
- Repeat public reachability validation for both owner-supplied Google Sites URLs from an environment
  that can access `sites.google.com` without authentication.
- Confirm the public privacy page displays the same reviewed policy as the in-app screen.
- Enter the URLs and App Privacy answers in App Store Connect manually.
