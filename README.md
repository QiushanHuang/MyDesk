# MyDesk

MyDesk is a native macOS workbench for organizing active projects, pinned files and folders, reusable snippets, and visual workspace canvases in one place.

It is built with SwiftUI, SwiftData, and Swift Package Manager, with a small core module that keeps export formats, ordering behavior, shell quoting, and canvas layout logic testable outside the app target.

## Highlights

- Workspace dashboard for tracking active work areas.
- Global library for pinned folders and files.
- Snippet library for reusable commands, notes, and references.
- Canvas view for arranging workspace resources and relationships visually.
- Import and export support through a JSON manifest model.
- Finder and Terminal helpers for opening resources and running selected actions.
- Focused unit tests for core ordering, canvas layout, export compatibility, and shell quoting behavior.

## Requirements

- macOS 14 or newer
- Xcode command line tools
- Swift 6 toolchain

## Build

Build the Swift package:

```bash
swift build
```

Run tests:

```bash
swift test
```

Build and launch the macOS app bundle:

```bash
./script/build_and_run.sh
```

The helper script builds the package, creates `dist/MyDesk.app`, copies the app icon, writes a minimal `Info.plist`, and launches the app.

## Project Structure

```text
Sources/MyDesk/       macOS SwiftUI app target
Sources/MyDeskCore/   testable core models and utilities
Tests/                XCTest coverage for core behavior
docs/                 design notes and implementation plans
script/               local build and run helpers
```

## Contributor

- Qiushan Huang ([@QiushanHuang](https://github.com/QiushanHuang))

## Notes

MyDesk stores local application data through SwiftData. Generated build artifacts such as `.build/`, `dist/`, and local Codex workspace metadata are intentionally ignored by Git.
