English | [Русский](docs/README.ru.md) | [Українська](docs/README.uk.md) | [Српски](docs/README.sr.md) | [Hrvatski](docs/README.hr.md) | [Română](docs/README.ro.md)

# Floatune

A small window for controlling Spotify on macOS. It floats above all other windows, shows and hides with a hotkey, and turns translucent when you leave it alone.

The window shows the artwork, track title and artist, previous / play-pause / next buttons, Spotify volume, and a progress bar you can drag to seek.

## Requirements

- macOS 14 or later
- The Spotify desktop app. Premium is not required.

## Install

Download `Floatune-*.zip` from the [latest release](https://github.com/azzz/floatune/releases/latest), unzip it and move `Floatune.app` to Applications.

The app has an ad-hoc signature, not a Developer ID, so macOS blocks the first launch. Remove the quarantine flag:

```
xattr -dr com.apple.quarantine /Applications/Floatune.app
```

Or try to open the app, then click "Open Anyway" in System Settings → Privacy & Security.

On first launch macOS asks whether Floatune may control Spotify. Allow it. After an update macOS may ask again, because every build has its own ad-hoc signature.

## Usage

| Action | How |
|---|---|
| Show or hide the window | ⌃⌥⌘S |
| Bring a dimmed window back to full opacity | Hover over it or press the hotkey |
| Move the window | Drag it anywhere. The position is saved |
| Settings and Quit | Right-click the window |

Settings cover the hotkey, the delay before dimming (1–15 s), the opacity of the dimmed window (10–90%), launch at login and the interface language. Changes apply immediately, except the language, which needs a restart.

Clicking the window doesn't take focus from the app you're working in.

## How it works

Floatune talks to the Spotify desktop app over Apple Events, the same commands AppleScript uses. Spotify announces track changes itself through the `com.spotify.client.PlaybackStateChanged` system notification, so nothing polls in the background. Floatune doesn't use the Spotify Web API and goes online only to download artwork.

Limitations:

- No queue of upcoming tracks. Only the Web API exposes it, and that requires OAuth and a developer account.
- The slider changes Spotify's own volume, not the system volume.
- Spotify sends no notification on seek. While the window is visible and a track is playing, Floatune re-reads the position every 5 seconds.
- If Spotify is closed, Floatune doesn't launch it and offers a button to open it.

## Languages

Floatune ships in English, Russian, Ukrainian, Serbian (Cyrillic), Croatian and Romanian and follows the system language. To pick another one, right-click the window → Settings… → Language, then click Restart.

### Add a language

1. Copy `Resources/en.lproj` to `Resources/<code>.lproj`, where `<code>` is the language code: `de`, `pl`, `pt-BR`.
2. Translate the values in `Localizable.strings` and `InfoPlist.strings`. Leave the keys on the left untouched and keep every `%@` placeholder.
3. Run `python3 scripts/check_strings.py`. It fails if a key is missing or extra, or if a translation changes the placeholders.
4. Build the app. The new language shows up in Settings → Language by itself; pick it and check every screen.

## Build from source

The Command Line Tools are enough; Xcode isn't required.

```
./scripts/build.sh
open build/Floatune.app
```

The script reads these environment variables:

| Variable | Sets | Default |
|---|---|---|
| `ARCHS` | Space-separated architectures, e.g. `"arm64 x86_64"` | Your Mac's architecture |
| `VERSION` | `CFBundleShortVersionString` | Value from `Resources/Info.plist` |
| `BUILD_NUMBER` | `CFBundleVersion` | Value from `Resources/Info.plist` |
| `SIGN_ID` | Codesigning certificate | Ad-hoc signature |

Gatekeeper doesn't check an app you built locally: macOS sets the quarantine flag only on downloaded files.

## Releases

CI checks translations and builds a universal app on every push to `main` and every pull request. To publish a release, push a tag:

```
git tag v0.2.0
git push origin v0.2.0
```

The workflow builds the app with the version from the tag and publishes a GitHub Release with the zip.

---

Floatune is not affiliated with Spotify AB. Spotify is a trademark of Spotify AB.
