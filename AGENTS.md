# AGENTS.md

Floatune is a floating Spotify controller for macOS: Swift, SwiftPM, AppKit for the panel, SwiftUI for its content. It talks to the Spotify desktop app over Apple Events.

## Commands

- `./scripts/build.sh` builds `build/Floatune.app`. The Command Line Tools are enough.
- `python3 scripts/check_strings.py` checks translations. CI runs it too.

The Command Line Tools ship no SwiftUI macro plugin, so `@State` and other SwiftUI macros don't compile locally. Keep view state in `@Observable` classes.

## READMEs

`README.md` (English) and `README.ru.md` (Russian) describe the same app in two languages.

- Change both files in the same commit. A fact, step, table row or section added to one goes into the other.
- Keep the headings in the same order, one-to-one.
- The top line of each file links to the other language.

## Localization

Translations live in `Resources/<language>.lproj`. `en.lproj` holds the source strings; every other language has exactly the same keys. `build.sh` copies all `.lproj` folders into the app bundle.

- Write UI text in English in code. SwiftUI initializers that take a string literal (`Text`, `Button`, `Toggle`, `LabeledContent`, `Section`) look it up as a key. Where the API takes a `String` — a ternary, a window title, a value stored in a model — wrap it in `String(localized: "…")`.
- Add every new key to `en.lproj/Localizable.strings` and to every other language. If you can't translate, copy the English text as the value and say so in the pull request.
- Remove keys that code no longer uses from all languages.
- Format numbers, durations and percentages with `FormatStyle` (`.formatted(…)`) instead of a key with a unit.
- An interpolated key, `String(localized: "Couldn't register \(name)")`, becomes `%@` for a `String` and `%lld` for an `Int`. Write that form in the `.strings` files. The check script skips interpolated keys in code, so compare them by hand.
- User-visible `Info.plist` values, such as `NSAppleEventsUsageDescription`, go to `InfoPlist.strings`.
- Leave non-UI strings unlocalized: AppleScript sources, UserDefaults keys, notification names, log messages.
- Run `python3 scripts/check_strings.py` before committing.

Adding a language is described in README, section "Add a language".
