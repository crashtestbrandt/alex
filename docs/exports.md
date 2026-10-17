# Exports

`export_presets.cfg` holds six presets. `just exports` builds all six into `build/<commit>/` and checks what
each one holds. docs/releases.md covers the release workflow that signs and publishes them.

## Presets

| Preset | Recipe | Writes | Notes |
| --- | --- | --- | --- |
| `Android` | `just export-android` | `android/alex.apk` | Debug-signed APK, arm64. `just install-android` puts it on a device. |
| `Google Play` | `just export-play` | `play/alex.aab` | Debug-signed AAB, arm64, through Godot's Gradle build. |
| `iOS` | `just export-ios` | `ios/alex.xcodeproj` | An Xcode project. Signing and the build happen in Xcode. |
| `macOS` | `just export-macos` | `macos/alex.zip` | Universal, ad-hoc signed. |
| `Windows Desktop` | `just export-windows` | `windows/alex.exe`, `alex.pck` | x86_64. |
| `Linux` | `just export-linux` | `linux/alex.x86_64`, `alex.pck` | x86_64. |

Every recipe goes through `tools/export.sh`. It empties the platform directory first and fails when Godot
writes no output.

- Every preset takes its version from `application/config/version` in `project.godot`, which holds the
  placeholder `0.0.0`. With `ALEX_VERSION=X.Y.Z` set, `tools/export.sh` stamps that version for the length of
  the export. A release sets it from the tag (docs/releases.md).
- `just testflight` uploads only with `ALEX_VERSION` set.
- Both Android presets take the build number as their version code: `ALEX_BUILD` in a release (docs/releases.md
  "Build numbers"), or the commit count. `tools/export.sh` stamps it for the length of the export.
- `Google Play` installs Godot's Gradle build template into `android/`, which git ignores. The first build
  downloads Gradle and its dependencies.

## Rules

`tools/check-export-presets.sh` enforces these in `just check` and in CI.

- Every preset includes `starters/*.json`. Starter packs are read with `DirAccess`, so nothing references
  them. The include keeps them in a build whose export mode is not "all resources".
- Every preset includes `PRIVACY.md`. The profile picker shows it (`PageText`), and Google Play's Families
  policy requires the policy inside the app. `tools/check-exports.sh` checks it is in each build.
- Every preset includes `GUIDE.md`. The profile picker shows it (`PageText`). `tools/check-exports.sh` checks
  it is in each build.
- `Android` and `Google Play` declare `RECORD_AUDIO`, support every screen size, and have no internet
  permission and no cloud backup. Both hold `version/code=1`, which the export stamps over.
- `Google Play` uses the Gradle build and exports an AAB.
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
  `tools/export.sh --export-release Android build/release/android/alex.apk`. The release workflow does this
  with the release key (docs/releases.md "Keys").
- **iOS.** The iOS preset carries the owner's Apple Developer Team ID, `9RM79FMS9B`. Godot refuses the export
  without one. Xcode signs automatically with that team once Xcode is signed in to its account (Xcode >
  Settings > Accounts). To sign with another account without committing it, set your own Team ID in
  `.godot/export_credentials.cfg`, which git ignores. `preset.1` is the iOS preset's index:

  ```ini
  [preset.1.options]

  application/app_store_team_id="ABCDE12345"
  ```

  The iOS simulator cannot run the Mobile renderer.

## Run on a device

`just run-ios` exports the iOS preset, builds it, installs it on the paired iPhone or iPad, and launches it
with its log in the terminal (`tools/run-ios.sh`). Ctrl-C stops the log and the app.

- `just run-ios <name>` picks a device when several are paired. `xcrun devicectl list devices` lists the names.
- The build replaces a TestFlight install of the app on that device.

Once per device, with someone at it:

| Step | Where |
| --- | --- |
| Pair it. iOS 27 pairs over Wi-Fi: Xcode > Window > Device Hub > + > Pair Nearby Device…. An older iOS needs a cable once. | Xcode and the device |
| Turn on Developer Mode, restart, and tap Turn On. | Settings > Privacy & Security > Developer Mode |

The script checks both and prints these steps when one is missing.

## TestFlight

`just testflight` exports the iOS preset, archives it and uploads it to App Store Connect
(`tools/testflight.sh`). The release workflow runs the same script with an App Store Connect API key on every
tag (docs/releases.md).

- It refuses a working tree with uncommitted changes, so every upload maps to a commit.
- The build number is `ALEX_BUILD` in a release, or the commit count. Xcode raises it when App Store Connect
  already holds that number.
- `tools/testflight.sh build/<commit> --export-only` signs the `.ipa` into `build/<commit>/ipa/` and uploads
  nothing.

Once per Apple account and app:

| Step | Where |
| --- | --- |
| Accept the latest Program License Agreement. | developer.apple.com/account |
| Sign Xcode in to the account. | Xcode > Settings > Accounts |
| Create the app record with the preset's bundle ID. The first upload registers the ID, so run `--export-only` first if the ID is not listed. | App Store Connect > Apps > + > New App |
| Create an internal testing group with automatic distribution, and add testers. | App Store Connect > the app > TestFlight |
| Each tester accepts the emailed invitation on the device, then installs from the TestFlight app. | The tester's phone |

## Validation

`just exports` exports every preset, then runs `tools/check-exports.sh build/<commit>`:

| Export | Checked |
| --- | --- |
| Every `.pck` | Mounted with `--main-pack`, it passes `tools/instr/pack_probe.gd`. Starter packs and style presets load. No `tests/`, `tools/`, `docs/` or `.mcp.json` shipped. |
| Android APK | Starter packs present. `RECORD_AUDIO` declared, `INTERNET` absent, every screen size supported (read with `aapt2`). |
| Play AAB | Starter packs present. `RECORD_AUDIO` declared, `INTERNET` absent. |
| iOS project | A microphone usage description. `TARGETED_DEVICE_FAMILY` is iPhone and iPad. |
| macOS app | A microphone usage description and the signed audio-input entitlement. |
| This machine's export | Boots headless for 300 frames with no error. |

`just exports` stays out of `just check`. It needs the templates and the SDKs. It takes about a minute once
Gradle has its dependencies.

To compile the iOS project for a device without signing:

```sh
xcodebuild -project build/<commit>/ios/alex.xcodeproj -scheme alex -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO build
```

## Verified on a device

- Android: a Galaxy Z Fold3 on Android 15 ran the release-signed APK (version code 20). It launched, asked for
  the microphone when the recording overlay opened, recorded a take, kept it, and played it from the object.
- iOS: an iPhone on iOS 27 installs from TestFlight and from `just run-ios`, asks for the microphone on first
  launch, records, and deletes a profile.
