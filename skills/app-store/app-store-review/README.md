# appstore-review

An AI skill that runs a comprehensive App Store review readiness audit on your
iOS project. It catches rejection risks — privacy manifest gaps, missing
subscription disclosures, incomplete metadata, and more — before you submit.

## Why this exists

About 25% of App Store submissions get rejected (1.93M out of 7.77M in 2024).
The top causes are well-documented but easy to miss: incomplete apps, missing
privacy declarations, subscription disclosure violations, and metadata issues.

This skill encodes those checks into a structured audit that your AI coding
agent runs directly in your project. It's ordered by rejection frequency using
Apple's 2024 Transparency Report data, so the highest-risk items get checked
first.

## What it covers

**Track 1 — Code & Entitlements** (8 sections)
- App completeness (Guideline 2.1) — the #1 rejection cause at 40%+ of cases
- Privacy manifest compliance (ITMS-91053/91061) — automated rejection since May 2024
- Subscription & IAP paywall disclosures (Guideline 3.1.1/3.1.2)
- Privacy & data handling (Guideline 5.1)
- App Transport Security
- Export compliance
- Entitlements & capabilities
- Code quality flags

**Track 2 — Submission Metadata** (6 sections)
- App Store Connect metadata fields
- Screenshots & previews
- App icon
- Version & build numbers
- Age rating
- Review notes

## Quick start

```bash
./scripts/install.sh appstore-review
```

Then in Claude Code, from your iOS project:

```
/appstore-review
```

For full setup instructions — including how to register the skill in your
CLAUDE.md, add a standing checklist, and what output to expect — see the
[Setup & Usage Guide](references/setup-guide.md).

## Files

| File | Purpose |
|------|---------|
| `SKILL.md` | The skill itself — what the AI agent reads and executes |
| `references/appstore-review-ref.md` | Catalog of ~60 Apple docs, WWDC sessions, and community resources |
| `references/setup-guide.md` | Installation, configuration, and usage instructions |

## Version

1.0.0 — Initial release covering all major App Store rejection categories for
iOS 17+ SwiftUI apps with StoreKit 2 subscriptions.
