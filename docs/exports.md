# Exports

`export_presets.cfg` holds five presets. `just exports` builds all five into `build/<commit>/` and checks what
each one holds.

## Presets

| Preset | Recipe | Writes | Notes |
| --- | --- | --- | --- |
| `Android` | `just export-android` | `android/alex.apk` | Debug-signed APK, arm64. `just install-android` puts it on a device. |
| `iOS` | `just export-ios` | `ios/alex.xcodeproj` | An Xcode project. Signing and the build happen in Xcode. |
| `macOS` | `just export-macos` | `macos/alex.zip` | Universal, ad-hoc signed. |
| `Windows Desktop` | `just export-windows` | `windows/alex.exe`, `alex.pck` | x86_64. |
| `Linux` | `just export-linux` | `linux/alex.x86_64`, `alex.pck` | x86_64. |

Every recipe goes through `tools/export.sh`. It empties the platform directory first and fails when Godot
writes no output.

Every preset takes its version from `application/config/version` in `project.godot`.

## Rules

`tools/check-export-presets.sh` enforces these in `just check` and in CI.

- Every preset includes `starters/*.json`. Starter packs are read with `DirAccess`, so nothing references
  them. The include keeps them in a build whose export mode is not "all resources".
- `Android` declares `RECORD_AUDIO`, supports every screen size, and has no internet permission and no
  cloud backup.
- `iOS` targets iPhone and iPad and carries a microphone usage description.
- `macOS` carries the audio-input entitlement and a microphone usage description.
- No preset holds a signing password or a release keystore.

The file names only the options Alex depends on. Godot fills every other option with its default. The editor
rewrites the file with every option and no comments once a preset is changed in the Export dialog. The check
still applies to the rewritten file.

Two project settings serve the mobile presets:

| Setting | Value | For |
| --- | --- | --- |
| `rendering/textures/vram_compression/import_etc2_astc` | `true` | Android refuses to export without ETC2/ASTC textures. |
| `audio/general/ios/session_category` | `2`, Play and Record | iOS has no microphone under the default category, Ambient. |

## Devices

| Platform | Runs on |
| --- | --- |
| Android | Phones and tablets, arm64, Android 7.0 (API 24) and newer. |
| iOS | iPhone XS, iPad (8th generation) and newer, iOS 15 and newer. `capabilities/performance_a12` sets the chip floor, Godot's default. |
| All | Any orientation, from `display/window/handheld/orientation`. |

## Machine setup

- **Export templates matching the Godot binary exactly.** Godot 4.7.2 needs `4.7.2.stable` templates. Install
  them from Editor > Manage Export Templates, or unpack `Godot_v4.7.2-stable_export_templates.tpz` into
  `export_templates/4.7.2.stable/` under Godot's data directory.
- **Android: a JDK, 17 or newer, and an Android SDK** with `platform-tools` and `build-tools;35.0.1`.
  `sdkmanager --sdk_root=<sdk> "platform-tools" "build-tools;35.0.1"` installs both. Set Editor Settings >
  Export > Android > Java SDK Path and Android SDK Path. A new editor settings file takes them from `JAVA_HOME`
  and `ANDROID_HOME`.
- **iOS: a Mac with Xcode, signed in to the Apple account of the preset's Team ID** (see "Signing").

## Signing

- **Android debug.** `just export-android` signs with `~/.android/debug.keystore`, the key Android Studio uses,
  and makes that key on first use. `GODOT_ANDROID_KEYSTORE_DEBUG_PATH`, `_USER` and `_PASSWORD` override it.
- **Android release.** Set `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `_USER` and `_PASSWORD`, then run
  `tools/export.sh --export-release Android build/release/android/alex.apk`. The Play Store takes an AAB, which
  needs a Gradle build. That is not set up yet.
- **iOS.** The iOS preset carries the owner's Apple Developer Team ID, `9RM79FMS9B`. Godot refuses the export
  without one. Xcode signs automatically with that team once Xcode is signed in to its account (Xcode >
  Settings > Accounts). To sign with another account without committing it, set your own Team ID in
  `.godot/export_credentials.cfg`, which git ignores. `preset.1` is the iOS preset's index:

  ```ini
  [preset.1.options]

  application/app_store_team_id="ABCDE12345"
  ```

  Then open `build/<commit>/ios/alex.xcodeproj`, pick a device as the run destination, and run. The iOS
  simulator cannot run the Mobile renderer.

## Validation

`just exports` exports every preset, then runs `tools/check-exports.sh build/<commit>`:

| Export | Checked |
| --- | --- |
| Every `.pck` | Mounted with `--main-pack`, it passes `tools/instr/pack_probe.gd`. Starter packs and style presets load. No `tests/`, `tools/`, `docs/` or `.mcp.json` shipped. |
| Android APK | Starter packs present. `RECORD_AUDIO` declared, `INTERNET` absent, every screen size supported (read with `aapt2`). |
| iOS project | A microphone usage description. `TARGETED_DEVICE_FAMILY` is iPhone and iPad. |
| macOS app | A microphone usage description and the signed audio-input entitlement. |
| This machine's export | Boots headless for 300 frames with no error. |

`just exports` stays out of `just check`. It needs the templates and the SDKs, and takes under a minute.

To compile the iOS project for a device without signing:

```sh
xcodebuild -project build/<commit>/ios/alex.xcodeproj -scheme alex -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO build
```

## Not yet verified

- A real device: install, the microphone prompt, and a recording through it (issue #4).
- The Android microphone prompt. `Recorder` does not request the permission before the first take.
