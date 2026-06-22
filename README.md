# MusicCount

**Match your play counts before cleaning up duplicates**

Swift 6.1 · SwiftUI · MediaPlayer · Swift Concurrency · Swift Testing · iOS 17.0+

[Download on the App Store](https://apps.apple.com/gb/app/musiccount/id6754639829)

---

## The Product

I built this because my own library was a mess. Years of re-importing albums and switching between Spotify and Apple Music left me with duplicate songs everywhere, each with different play counts. It was also my first Swift app. I wanted to learn iOS development properly, and building something I'd actually use seemed like the best way to do it.

MusicCount scans your library, groups duplicates by normalised title and artist, and lets you pick the version you want to keep. Queue it enough times to match the play count of the duplicate, then delete the duplicate yourself. Your listening history stays intact on the song that matters.

---

## Features

### Intelligent Duplicate Detection

Nothing worse than seeing your most-played song split across three versions. The app normalises strings to catch duplicates across case variations, whitespace differences, and encoding quirks. It crunches through thousands of songs on a background thread, grouping by both title and artist so you don't get false positives from different songs with the same name. Groups with the biggest play count gaps float to the top.

### Interactive Play Count Comparison

A side-by-side view with blurred album artwork in the background. Tap the card for the version you want to keep, and that's the one that gets queued. Two modes: **Match Mode** queues it enough times to match the duplicate's play count, while **Add Mode** adds plays equal to the duplicate's total.

Hooks directly into Apple's music player with two queue behaviours: **Insert Next** slots songs after whatever's playing, and **Replace Queue** clears everything and starts fresh. Once you've played through the queue, you can delete the duplicate knowing your play history is preserved on the right track.

### Smart Dismissal System

You can dismiss individual songs from groups with 3+ versions, or swipe to bin an entire group. Dismissals persist between launches, because nobody wants to dismiss the same suggestion every time they open the app.

### Sorting & Search

Browse your entire library sorted by play count, title, artist, album, or version count, each ascending or descending. Seven sort options in total for the suggestions view. Search is real-time across titles, artists, and albums with proper Unicode handling. Search narrows things down first, then sort reorders what's left.

### Accessibility

VoiceOver labels and hints on every interactive element. Tab bar badges show the suggestion count at a glance. Comparison cards are grouped so screen readers don't have to wade through each element individually. Dynamic Type works throughout, and everything uses semantic font styles.

---

## How It's Built

### Architecture Decisions

As a first iOS project, I wanted to start with good habits rather than learn bad ones.

**Native State Management**

With iOS 17's new observation system, the traditional ViewModel layer has become optional for most apps. I leaned into this, so views stay thin and business logic lives in services. No boilerplate, no manual change notifications. Services are shared via dependency injection, which gives global access without falling back on singletons.

**Modular Package Architecture**

All the features live in a separate Swift Package. The app target is just a thin wrapper that imports it and launches the main view. Keeps things modular and testable, and means you can modify feature code without touching project configuration files. Tests sit alongside the feature code rather than in a separate target.

**Background Thread Library Scanning**

Querying the music library can hang the main thread when you've got thousands of songs. I offloaded the query onto a background thread, then hopped back to the main thread for UI updates. The interface stays responsive during the initial load, with a proper loading state that reflects actual progress.

### Security & Privacy

- **Data Not Collected:** App Store privacy label confirms zero data collection
- **Sandboxed Media Access:** Proper permission handling for all authorisation states
- **On-Device Processing:** No network calls, everything happens locally
- **Local Storage:** Dismissals saved locally with prefixed keys to avoid collisions
- **Zero Dependencies:** No external frameworks or analytics SDKs

### Performance

- **1.7 MB App Size:** No bloat, just the essentials
- **Background Threading:** All library queries happen off the main thread, so the UI stays snappy even with large libraries
- **Lazy Image Loading:** Album artwork fetched at thumbnail size rather than full resolution, which makes a real difference to memory usage
- **Normalised String Caching:** Duplicate detection keys get computed once per song, not on every comparison
- **Efficient Filtering:** Active suggestions are a computed property, so dismissing something doesn't trigger a full re-scan

### Accessibility

Built to Apple's Human Interface Guidelines. Every button has proper labels and hints for screen readers. Complex UI components are grouped to keep navigation manageable. All text uses semantic font styles so system-wide text size preferences are respected.

### Testing

Overkill for a side project? Maybe. But I wanted to learn how to test properly, not just ship something. Built the test suite with Swift's modern testing framework. Coverage includes: service tests for grouping logic, dismissal persistence, and case insensitivity; queue behaviour tests for insertion modes and edge cases; model tests for validation and aggregation; and sort tests for all seven algorithms. Production uses real library data, while tests and UI development use a mock service with deterministic random generation.

### Continuous Integration

Pull requests to `master`, pushes to `master`, and manual workflow dispatches run `.github/workflows/ci.yml`. The required CI check is `MusicCount simulator tests`.

The required check intentionally uses the checked-in Xcode workspace and test plan rather than host SwiftPM. It builds the app and test bundle for an iOS simulator, then runs the package tests plus one deterministic app-launch UI smoke test:

```sh
xcodebuild build-for-testing \
  -workspace MusicLibraryVerification.xcworkspace \
  -scheme MusicLibraryVerification \
  -testPlan MusicLibraryVerification \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:MusicCountFeatureTests \
  -only-testing:MusicCountUITests/MusicLibraryVerificationUITests/testMockDataLaunchShowsLibraryAndSuggestions

xcodebuild test-without-building \
  -workspace MusicLibraryVerification.xcworkspace \
  -scheme MusicLibraryVerification \
  -testPlan MusicLibraryVerification \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:MusicCountFeatureTests \
  -only-testing:MusicCountUITests/MusicLibraryVerificationUITests/testMockDataLaunchShowsLibraryAndSuggestions
```

`MusicCount/MusicLibraryVerification.xctestplan` covers both `MusicCountFeatureTests` from `MusicCountPackage` and `MusicCountUITests` from the app project. This matters because package source imports UIKit, so raw host `swift test` can fail before test discovery on macOS even when the package passes through the simulator harness.

Manual workflow dispatch also runs `Full MusicCount UI verification`, which executes the full verification test plan on the same simulator. That deeper suite is intentionally manual because hosted iOS UI tests are slower and more timing-sensitive than the package and launch-smoke gate.

As of 2026-06-22, GitHub's `macos-26` runner image is generally available and includes Xcode 26.5 plus iPhone 17 Pro simulators. CI pins `runs-on: macos-26` and selects `/Applications/Xcode_26.5.app/Contents/Developer` explicitly so default-image changes do not silently move the project to another Xcode.

The workflow keeps permissions to read-only repository contents, cancels superseded runs on the same ref, uploads the Xcode result bundle and build log on failure, and does not cache DerivedData or SwiftPM artifacts yet. The project has no external Swift package dependencies today, and DerivedData caches are easy to make stale across Xcode image updates; add caching only after CI timings show a real need.

Deployment is intentionally not enabled. A TestFlight or App Store workflow should be added separately once the repository has App Store Connect API credentials, signing certificates or automatic signing set up for CI, provisioning profiles where needed, and a documented release approval path.

### Repository Hygiene

GitHub Issues are the tracker for bugs, features, maintenance work, and planning slices. The repository includes issue forms, a pull request template, CODEOWNERS, and Dependabot version updates for GitHub Actions and Swift Package Manager manifests.

Repository settings should keep secret scanning and push protection enabled. The `master` branch is protected by a repository ruleset that requires pull requests, one approving review, resolved conversations, the `MusicCount simulator tests` status check, and blocks branch deletion and force pushes.

---

## Tech Stack

**UI:** SwiftUI (iOS 17.0+)

**Language:** Swift 6.1 with strict concurrency checking

**Concurrency:** async/await, actors, main thread isolation

**State:** Native observation system, dependency injection

**Testing:** Swift Testing framework

**Architecture:** Modular package structure

---

## License

All rights reserved. This repository is public for portfolio purposes only.

---

## Links

[App Store](https://apps.apple.com/gb/app/musiccount/id6754639829) · [Portfolio](https://jacobrees.co.uk)
