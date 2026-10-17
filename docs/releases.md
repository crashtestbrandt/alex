# Releases

A `vX.Y.Z` tag on `main` releases every platform. `.github/workflows/release.yml` builds, signs and publishes
it.

## Cut a release

1. Raise `application/config/version` in `project.godot` in a pull request, and merge it.
2. On an up-to-date `main`, run `just release`. It tags `HEAD` as `v<version>` and pushes the tag.
3. The release workflow runs. The GitHub Release leaves draft once every job passes.

- A version is three numbers, `X.Y.Z`. iOS and Google Play refuse anything else.
- The build number is the commit count on `main`. iOS and Android both use it.
- The release notes are the merged PR titles since the previous tag.
- Running the workflow by hand (Actions > release > Run workflow) builds, signs and checks every platform and
  publishes nothing.

## What a release publishes

| Platform | Where | Signed with |
| --- | --- | --- |
| Linux | GitHub Release, `alex-<version>-linux-x86_64.tar.gz` | Nothing. |
| Windows | GitHub Release, `alex-<version>-windows-x86_64.zip` | Nothing. SmartScreen warns on first launch. |
| macOS | GitHub Release, `alex-<version>-macos.zip` | Developer ID, notarized and stapled. |
| Android | GitHub Release, `alex-<version>-android.apk` | The release key. |
| Android | Google Play, internal testing track | The release key, as the AAB's upload key. |
| iOS | TestFlight | Cloud-managed distribution certificate. |

The APK and the Play build carry the same signature, because Play signs with the release key as its app
signing key. A device can move between the two without losing its recordings.

## Google Play

- The app is `io.github.crashtestbrandt.alex` in a personal developer account.
- Play App Signing holds the release key, uploaded with Google's PEPK tool. The release key is also the upload key.
- Automatic protection is off. Its failed-check prompt would appear on the learner's screen, and Google collects
  data from apps it protects. Play applies the setting when it processes a bundle, so it stays off for every upload.
- Version codes 1 to 3 were uploaded by hand. A CI upload uses the commit count on `main`, which is higher.
- Production needs a closed test with 12 testers opted in for 14 days in a row, because the account is personal.

## Jobs

| Job | Runner | Does |
| --- | --- | --- |
| `plan` | Ubuntu | Checks the tag matches `project.godot` and sits on `main`. Drafts the GitHub Release. |
| `desktop` | Ubuntu | Exports Linux and Windows, checks them, attaches them. |
| `android` | Ubuntu | Exports the APK and the AAB, checks them, attaches the APK, uploads the AAB to Play. |
| `macos` | macOS | Exports, signs, notarizes (`tools/notarize-macos.sh`), checks, attaches. |
| `ios` | macOS | Exports, archives and uploads to TestFlight (`tools/testflight.sh`). |
| `publish` | Ubuntu | Takes the release out of draft. |

A failed job leaves the release in draft. Re-run the failed job from the Actions page.

## Secrets

Every signing secret lives in the `release` environment. Only `main` and `v*` tags can use it.

| Secret | What |
| --- | --- |
| `ANDROID_RELEASE_KEYSTORE_BASE64` | The release keystore, base64. |
| `ANDROID_RELEASE_KEYSTORE_USER` | Its key alias, `alex`. |
| `ANDROID_RELEASE_KEYSTORE_PASSWORD` | Its password. The keystore and the key share it. |
| `ASC_KEY_P8` | The App Store Connect API key, Admin role, the `.p8` file's contents. |
| `ASC_KEY_ID` | The API key's ID. |
| `ASC_ISSUER_ID` | The API key's issuer ID. |
| `MACOS_DEVELOPER_ID_P12_BASE64` | The Developer ID Application certificate and key, PKCS 12, base64. |
| `MACOS_DEVELOPER_ID_P12_PASSWORD` | The PKCS 12 password. |
| `PLAY_SERVICE_ACCOUNT_JSON` | The JSON key of `alex-ci@alex-releases.iam.gserviceaccount.com`. Play Console grants it "Release apps to testing tracks" on this app only. Without it, the Play upload is skipped with a warning. |

An upload goes to the internal track as `completed`. The `PLAY_RELEASE_STATUS` variable overrides the status, for
example with `draft`.

## Keys

The owner keeps a backup of each key outside GitHub. GitHub secrets cannot be read back.

| Key | Lasts | Lost means |
| --- | --- | --- |
| Android release keystore | Until 2081. | No update for anyone who installed the APK. |
| Developer ID certificate | Until 2027-11-14. | Make a new one. Builds already notarized keep working. |
| App Store Connect API key | Until revoked. | Revoke it and make a new one. |
| Play service account key | Until revoked. | Delete it in Google Cloud and make a new one. |

## Pull requests

`check.yml` exports Linux, Windows and a debug-signed Android APK on every pull request and runs
`tools/check-exports.sh` on them. A pull request restores caches and saves none, and uploads no artifact.
