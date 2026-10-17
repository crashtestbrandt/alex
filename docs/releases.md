# Releases

A `vX.Y.Z` tag on `main` takes every platform as far as it can go, with no step by hand.
`.github/workflows/release.yml` builds, signs, publishes and submits it. A store step that still needs a person
is a gap to close.

## Cut a release

1. On an up-to-date `main`, run `just release X.Y.Z`. It tags `HEAD` as `vX.Y.Z` and pushes the tag.
2. The release workflow runs. The GitHub Release leaves draft once every build job passes.
3. The App Store job waits for Apple to process the build, then sends the version to App Review.

- The tag is the version. `project.godot` keeps the placeholder `0.0.0`, and no pull request changes it.
- The workflow passes the tag's version to every export as `ALEX_VERSION`.
- A version is three numbers, `X.Y.Z`. iOS and Google Play refuse anything else.
- `just release` refuses a version lower than the latest tag, because iOS and Google Play refuse one too.
- The release notes are the merged PR titles since the previous tag.
- Running the workflow by hand (Actions > release > Run workflow) builds, signs and checks every platform as
  `0.0.0` and publishes nothing.

## Build numbers

Every tag gets its own build number: the commit count on `main` times 100, plus the candidate's number, or 99
for a final. iOS takes it as the build number and Android as the version code.

| Tag | Commit count | Build number |
| --- | --- | --- |
| `v0.1.2-rc.1` | 37 | 3701 |
| `v0.1.2-rc.2` | 37 | 3702 |
| `v0.1.2` | 37 | 3799 |

- A final outranks its candidates on the same commit, so Play and TestFlight take both.
- A commit holds up to 98 candidates.
- Every export stamps the tag, such as `0.1.2-rc.1`, and the build number into `project.godot`'s
  `alex/build/*` settings. The profile picker shows them in a corner, so a tester can say which build they have.
- A local export, with no `ALEX_BUILD`, uses the commit count alone.

## Release candidates

`just release X.Y.Z-rc.N` tags a release candidate, for testers:

| Where | A candidate | A final `vX.Y.Z` |
| --- | --- | --- |
| GitHub | A pre-release, never "Latest", with every download named `alex-X.Y.Z-rc.N-…` | The release, marked "Latest" |
| TestFlight | The build, as `X.Y.Z`, for internal and external testers | The same |
| Google Play | The internal and closed testing tracks | Those tracks, the listing, and production |
| App Store | Nothing | Listing and App Review |

- A candidate builds as `X.Y.Z`, because iOS and Google Play take only digits. The rc number is in the tag,
  the GitHub release, the file names, the Play release name and the build stamp.
- A final tag on a candidate's commit submits the candidate's TestFlight build to App Review, the build testers
  had: the lowest processed build from that commit's first number on.
- Versions order as `0.1.1` < `0.1.2-rc.1` < `0.1.2-rc.2` < `0.1.2`. A candidate after its own final is refused.
- A final needs a candidate of its version on the same commit. `just release` refuses one without, and so does
  the release workflow, for a tag pushed by hand.
- The `REQUIRE_CANDIDATE` repository variable holds the rule, and it is `true`. Set it to `false` to let a final
  release without a candidate; `just release` then says the stores get a build no tester had.

## What a release publishes

| Platform | Where | Signed with |
| --- | --- | --- |
| Linux | GitHub Release, `alex-<version>-linux-x86_64.tar.gz` | Nothing. |
| Windows | GitHub Release, `alex-<version>-windows-x86_64.zip` | Nothing. SmartScreen warns on first launch. |
| macOS | GitHub Release, `alex-<version>-macos.zip` | Developer ID, notarized and stapled. |
| Android | GitHub Release, `alex-<version>-android.apk` | The release key. |
| Android | Google Play, internal and closed testing tracks | The release key, as the AAB's upload key. |
| iOS | TestFlight | Cloud-managed distribution certificate. |

The APK and the Play build carry the same signature, because Play signs with the release key as its app
signing key. A device can move between the two without losing its recordings.

## Google Play

- The app is `io.github.crashtestbrandt.alex` in a personal developer account.
- Play App Signing holds the release key, uploaded with Google's PEPK tool. The release key is also the upload key.
- Automatic protection is off. Its failed-check prompt would appear on the learner's screen, and Google collects
  data from apps it protects. Play applies the setting when it processes a bundle, so it stays off for every upload.
- Version codes 1 to 3 were uploaded by hand. A CI upload uses the build number ("Build numbers"), which is
  higher.
- Production needs a closed test with 12 testers opted in for 14 days in a row, because the account is personal.
- Every upload also tries production, in an edit of its own. Until Google grants production access, Play
  refuses and the job warns. After that, every tag reaches production with no change here.
- The service account needs "Release to production" in Play Console for that, as well as "Release apps to
  testing tracks".
- Closed testers are the members of `alex-testers@googlegroups.com`, which anyone can join. The README's
  "Get Alex" section lists the steps. The Play API cannot manage testers on this kind of track, so the group
  was attached once in Play Console.
- The listing is `store/play/listing.json` and `description.txt`. `just store-graphics` renders its icon,
  feature graphic and five 1920x1080 screenshots into `store/play/`.
- Every upload sets the listing, the icon, the feature graphic and the phone and tablet screenshots. They go in
  an edit of their own after the bundle, so a bad listing never holds a build back from testers.
- The API has no Chromebook image type, so that set was uploaded once in Play Console.

## App Store

- The app is `io.github.crashtestbrandt.alex`, "Alex Language Explorer", in the Kids category for ages 5 and
  under. Its age rating answers are in `store/app-store/age-rating.json`.
- External TestFlight testers join the "Testers" group through its public link,
  `https://testflight.apple.com/join/2AYBxYbr`. They get no App Store Connect access.
- Every tag sends its build to that group (`tools/app-store.sh beta`), with "What to Test" from `metadata.json`.
  Apple's Beta App Review checks the first build of each version, usually within a day.
- `tools/app-store.sh beta-setup` sets the test information, the review contact and the group. The release
  workflow runs it before each build, and it changes nothing when they are already set.
- `just app-store X.Y.Z` sets the listing from `store/app-store/`: `metadata.json`, `description.txt`, the age
  rating and the iPhone and iPad screenshots. `just store-graphics` renders the screenshots.
- `just app-store-submit X.Y.Z` attaches the newest processed build of X.Y.Z and sends it to App Review.
- A tag runs all of it as `tools/app-store.sh release X.Y.Z <build>`: it withdraws an older version still in
  review, sets the listing, waits up to 90 minutes for the build, and submits.
- An approved version goes live by itself (`releaseType` `AFTER_APPROVAL`).
- The review contact's phone is the `APP_REVIEW_PHONE` secret. Without it, the contact is copied from an earlier
  version.
- Three settings have no API and were set once in App Store Connect: App Privacy ("Data Not Collected"), the
  EU trader status (non-trader), and price and availability (free, every country).
- The Mac App Store is not set up. It needs Mac App Store signing, the App Sandbox and a `.pkg` upload.

## Jobs

| Job | Runner | Does |
| --- | --- | --- |
| `plan` | Ubuntu | Reads the version from the tag and checks the tag sits on `main`. Drafts the GitHub Release. |
| `desktop` | Ubuntu | Exports Linux and Windows, checks them, attaches them. |
| `android` | Ubuntu | Exports the APK and the AAB, checks them, attaches the APK, uploads the AAB to Play. |
| `macos` | macOS | Exports, signs, notarizes (`tools/notarize-macos.sh`), checks, attaches. |
| `ios` | macOS | Exports, archives and uploads to TestFlight (`tools/testflight.sh`). |
| `testflight` | Ubuntu | After `ios`: the build to the external group, with Beta App Review when Apple asks (`tools/app-store.sh beta`). |
| `publish` | Ubuntu | Takes the release out of draft. |
| `app-store` | Ubuntu | After `ios`: sets the listing, waits for Apple to process the build, submits it (`tools/app-store.sh`). |

A failed build job leaves the release in draft. `app-store` does not hold the release back. Re-run a failed job
from the Actions page.

## Secrets

Every signing secret lives in the `release` environment. Only `main` and `v*` tags can use it.

| Secret | What |
| --- | --- |
| `ANDROID_RELEASE_KEYSTORE_BASE64` | The release keystore, base64. Its key alias, `alex`, is written in `release.yml`. |
| `ANDROID_RELEASE_KEYSTORE_PASSWORD` | Its password. The keystore and the key share it. |
| `ASC_KEY_P8` | The App Store Connect API key, Admin role, the `.p8` file's contents. |
| `ASC_KEY_ID` | The API key's ID. |
| `ASC_ISSUER_ID` | The API key's issuer ID. |
| `APP_REVIEW_PHONE` | The number App Review may call. Kept out of the repository. |
| `MACOS_DEVELOPER_ID_P12_BASE64` | The Developer ID Application certificate and key, PKCS 12, base64. |
| `MACOS_DEVELOPER_ID_P12_PASSWORD` | The PKCS 12 password. |
| `PLAY_SERVICE_ACCOUNT_JSON` | The JSON key of `alex-ci@alex-releases.iam.gserviceaccount.com`. Play Console grants it "Release apps to testing tracks" on this app only. Without it, the Play upload is skipped with a warning. |

An upload goes to the internal track and the closed testing track (`alpha`) as `completed`. Closed testers get
each release with no step in Play Console. The `PLAY_TRACKS` variable overrides the tracks, and
`PLAY_RELEASE_STATUS` overrides the status, for example with `draft`.

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
