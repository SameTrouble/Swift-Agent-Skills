---
name: appstore-review
version: "1.1.0"
description: >
  App Store review readiness audit for iOS apps. Scans the codebase,
  entitlements, Info.plist, privacy manifests, paywall/subscription UI, and
  metadata for anything that could trigger a warning or rejection during
  App Store review. Invoke explicitly when preparing a submission.
  Do NOT trigger automatically.
author: 3 Paws AI Studio
license: MIT
agents:
  - claude-code
tags:
  - ios
  - app-store
  - review
  - submission
  - privacy-manifest
  - storekit
trigger: manual
last_verified: "2026-03-30"
---

# App Store Review Readiness Audit

## Purpose
Catch every issue that could cause an App Store warning or rejection — before
submitting. This skill runs a two-track audit: **code/entitlements** and
**submission metadata**. It is ordered by rejection frequency (highest-risk first)
based on Apple's 2024 Transparency Report data.

**Reference file**: `references/appstore-review-ref.md` contains the full
catalog of Apple docs, WWDC sessions, and community resources backing each check.

---

## How to Run the Audit

When invoked, execute every section below **in order**. For each check:
1. Inspect the relevant files/config in the project
2. Report **PASS**, **WARN**, or **FAIL** with a one-line explanation
3. At the end, produce a summary table of all results

Do NOT skip sections. Do NOT ask the user which sections to run — run them all.

---

## Track 1 — Code & Entitlements Audit

### 1.1 App Completeness (Guideline 2.1) — #1 rejection cause

This accounts for over 40% of all unresolved rejections.

- [ ] App launches without crashing on a clean install
- [ ] No placeholder or Lorem Ipsum text anywhere in the UI (search all `.swift` files and asset catalogs)
- [ ] No TODO/FIXME/HACK comments that indicate unfinished work visible to the user
- [ ] All navigation paths are functional — no dead-end screens or unimplemented buttons
- [ ] All URLs (support, privacy policy, terms) are valid and load correctly
- [ ] Login/onboarding flows complete without errors
- [ ] Deep links and universal links resolve correctly (if applicable)
- [ ] App works in airplane mode or gracefully handles no-network state

### 1.2 Privacy Manifest (ITMS-91053 / ITMS-91061) — automated rejection

Enforced since May 1, 2024. Missing declarations cause rejection before human
review.

- [ ] `PrivacyInfo.xcprivacy` exists in the app target
- [ ] All five Required Reason API categories are checked for usage:
  - `NSPrivacyAccessedAPICategoryFileTimestamp` — `creationDate`, `modificationDate`, `stat()`
  - `NSPrivacyAccessedAPICategorySystemBootTime` — `systemUptime`, `mach_absolute_time()`
  - `NSPrivacyAccessedAPICategoryDiskSpace` — `volumeAvailableCapacityKey`, `NSFileSystemFreeSize`
  - `NSPrivacyAccessedAPICategoryActiveKeyboards` — `UITextInputMode.activeInputModes`
  - `NSPrivacyAccessedAPICategoryUserDefaults` — `UserDefaults`
- [ ] Every used Required Reason API has a matching declaration with an approved reason code
- [ ] `NSPrivacyCollectedDataTypes` accurately reflects all data the app collects
- [ ] `NSPrivacyTracking` is set correctly (`true` only if using IDFA/ATT)
- [ ] Third-party SDKs on Apple's list include their own privacy manifests
- [ ] Generate a Privacy Report via Xcode Organizer to cross-check declarations

### 1.3 Subscription & IAP Compliance (Guideline 3.1.1 / 3.1.2)

Second-highest risk area for subscription apps.

**Paywall UI — required disclosures (Guideline 3.1.2(c) + Schedule 2 §3.8(b)):**
- [ ] Subscription name and duration displayed
- [ ] Full renewal price is the **most prominent pricing element** (not monthly equivalent)
- [ ] Free trial duration and post-trial price shown (if applicable)
- [ ] Tappable link to Terms of Use present and functional
- [ ] Tappable link to Privacy Policy present and functional
- [ ] "Restore Purchases" button/mechanism is accessible (Guideline 3.1.1)
- [ ] No dark patterns: no fake urgency, no hiding annual pricing, no pre-selected expensive option without clear disclosure
- [ ] Subscription auto-renewal language present (e.g., "Subscriptions auto-renew unless canceled at least 24 hours before the end of the current period")
- [ ] Cancellation/management instructions present (or use `AppStore.showManageSubscriptions(in:)`)

**Note:** In-app disclosures alone are not sufficient. Section 2.1 checks that
Terms of Use and Privacy Policy links also appear in the App Store description
or EULA field in App Store Connect — Apple requires both.

**StoreKit implementation:**
- [ ] Using StoreKit 2 (not deprecated StoreKit 1 / `SKPaymentQueue`)
- [ ] Transactions are verified (JWS verification or RevenueCat handling)
- [ ] Entitlements update correctly after purchase, restore, and subscription expiry
- [ ] Grace period handling implemented (if enabled in App Store Connect)
- [ ] Sandbox purchases work correctly in the app

**App Store Connect configuration:**
- [ ] IAP products are in "Ready to Submit" or "Approved" status
- [ ] Review screenshot uploaded for each IAP
- [ ] Subscription group configured correctly
- [ ] Pricing set for all required territories

### 1.4 Privacy & Data Handling (Guideline 5.1)

- [ ] Privacy Policy URL is set in App Store Connect and is accessible
- [ ] Privacy Policy URL is also accessible from within the app
- [ ] App Privacy nutrition labels in App Store Connect match actual data collection
- [ ] If app uses IDFA: ATT prompt is implemented (`ATTrackingManager.requestTrackingAuthorization`)
- [ ] If app uses third-party AI: explicit consent for data sharing (Guideline 5.1.2(i), enforcement Nov 2025)
- [ ] Account deletion option provided if the app has account creation (Guideline 5.1.1(v))

### 1.5 App Transport Security

- [ ] No `NSAllowsArbitraryLoads = YES` in Info.plist (unless justified)
- [ ] All network connections use HTTPS / TLS 1.2+
- [ ] If domain exceptions exist via `NSExceptionDomains`, each has a documented justification

### 1.6 Export Compliance

- [ ] `ITSAppUsesNonExemptEncryption` is set in Info.plist
- [ ] If only standard HTTPS (URLSession), value is `NO` (exempt)
- [ ] If custom encryption is used, value is `YES` and CCATS/ERN documentation exists

### 1.7 Entitlements & Capabilities

- [ ] Only required entitlements are present (no unused capabilities)
- [ ] App ID is explicit (non-wildcard) — required for IAP
- [ ] In-App Purchase capability is enabled in Signing & Capabilities
- [ ] Push Notification entitlement present only if push is implemented
- [ ] No `com.apple.developer.in-app-payments` unless Apple Pay is used (this is NOT the IAP entitlement)

### 1.8 Code Quality Flags

- [ ] No `print()` statements in production code (use `os.Logger`)
- [ ] No force-unwraps (`!`) outside of tests
- [ ] No hardcoded API keys, secrets, or tokens in source
- [ ] No references to internal/debug URLs, test servers, or staging endpoints
- [ ] No `#if DEBUG` blocks that expose test UI in release builds

---

## Track 2 — Submission Metadata Checklist

### 2.1 App Store Connect Metadata

- [ ] App Name: ≤30 characters, no keyword stuffing
- [ ] Subtitle: ≤30 characters
- [ ] Description: hook in first line, benefits over features, no placeholder text
- [ ] Keywords: ≤100 characters, comma-separated, no spaces after commas, no duplicates of title words
- [ ] Promotional Text: set (editable without new version)
- [ ] What's New: written in plain language, user-benefit framing
- [ ] Support URL: set and loads correctly
- [ ] Privacy Policy URL: set and loads correctly
- [ ] If app has subscriptions: Terms of Use (EULA) link in App Description OR custom EULA set in App Store Connect
- [ ] If app has subscriptions: Privacy Policy link in App Description
- [ ] If app has subscriptions: auto-renewal language in App Description (price, duration, cancellation)
- [ ] Copyright: set with current year and correct entity name
- [ ] Primary Category and optional Secondary Category set appropriately

### 2.2 Screenshots & Previews

- [ ] At least one screenshot set for 6.5" or 6.9" iPhone
- [ ] iPad screenshots if universal app
- [ ] Screenshots are in JPEG or PNG format
- [ ] No placeholder or obviously fake screenshots
- [ ] App previews ≤30 seconds, H.264 or ProRes 422 (if used)
- [ ] Screenshots show actual app UI (not misleading)

### 2.3 App Icon

- [ ] 1024x1024 App Store icon provided
- [ ] Icon does not contain transparency or alpha channel
- [ ] Icon is not a duplicate of another app's icon
- [ ] In-app icon matches App Store icon

### 2.4 Version & Build

- [ ] Version number bumped appropriately (semantic versioning)
- [ ] Build number incremented from last upload
- [ ] Both app target AND extension targets (if any) have matching version/build
- [ ] Built with the current required SDK version

### 2.5 Age Rating

- [ ] Age rating questionnaire completed in App Store Connect
- [ ] Rating reflects actual content (especially AI/chatbot content if applicable)
- [ ] If expanded age ratings apply (13+/16+/18+): responses updated by Jan 31, 2026 deadline

### 2.6 Review Notes

- [ ] If app has login: demo credentials provided in review notes
- [ ] If app has special flows (subscriptions, hardware features): instructions provided
- [ ] If app uses on-device AI: note about device/OS requirements
- [ ] If app has subscriptions: review notes describe where in-app subscription disclosures can be found (paywall location, settings, etc.)
- [ ] Contact information for the reviewer is current

---

## Output Format

After running all checks, produce this summary:

```
## App Store Review Audit — [App Name]
Date: [YYYY-MM-DD]

### Results
| # | Check | Status | Notes |
|---|-------|--------|-------|
| 1.1 | App Completeness | PASS/WARN/FAIL | ... |
| 1.2 | Privacy Manifest | PASS/WARN/FAIL | ... |
| ... | ... | ... | ... |

### Critical Issues (FAIL — must fix before submission)
- [list]

### Warnings (WARN — should fix, risk of rejection)
- [list]

### Recommendations
- [list]
```

If there are zero FAIL items, state: "No blocking issues found. Ready for submission."

---

## When Requirements Change

Apple publishes enforcement deadlines at:
`https://developer.apple.com/news/upcoming-requirements/`

If the user mentions a specific deadline or new requirement, cross-reference
with `references/appstore-review-ref.md` Section 8 for the latest tracked changes.
