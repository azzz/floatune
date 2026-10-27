## Install

1. Download `Floatune-*.zip`, unzip it and move `Floatune.app` to Applications.
2. The app has an ad-hoc signature, not a Developer ID, so macOS blocks the first launch. Remove the quarantine flag:
   ```
   xattr -dr com.apple.quarantine /Applications/Floatune.app
   ```
   Or try to open the app, then click "Open Anyway" in System Settings → Privacy & Security.
3. On first launch, allow Floatune to control Spotify. After an update macOS may ask again.

The default hotkey is ⌃⌥⌘S. Right-click the window for settings.

Инструкция на русском: [README.ru.md](https://github.com/azzz/floatune/blob/main/README.ru.md#установка).
