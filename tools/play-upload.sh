#!/usr/bin/env bash
# Upload an AAB to Google Play tracks: tools/play-upload.sh <aab> <version name>. The release is named
# "<version name> (<version code>)", such as "0.1.0 (1)".
#
# The release workflow runs this (docs/releases.md). It needs:
#
# - PLAY_SERVICE_ACCOUNT_JSON: the path to a Google Cloud service account key that Play Console has granted
#   release rights on the app.
# - PLAY_TRACKS: the tracks, space-separated, `internal alpha` when unset. `alpha` is the closed testing track.
# - PLAY_RELEASE_STATUS: `completed` when unset. An app with no release published from Play Console takes only `draft`.
# - PLAY_PRODUCTION: `try` when unset, which also sends the release to production and only warns when Play
#   refuses. `skip` leaves production out.
#
# It talks to the Play Developer API with curl, openssl and jq, so the key reaches no third-party code.
set -euo pipefail

if [[ $# -ne 2 || ! -f "$1" ]]; then
	printf 'usage: tools/play-upload.sh <aab> <version name>\n' >&2
	exit 2
fi
aab="$1"
version_name="$2"
key_file="${PLAY_SERVICE_ACCOUNT_JSON:?PLAY_SERVICE_ACCOUNT_JSON is not set}"
tracks="${PLAY_TRACKS:-internal alpha}"
status="${PLAY_RELEASE_STATUS:-completed}"
package="io.github.crashtestbrandt.alex"
api="https://androidpublisher.googleapis.com/androidpublisher/v3/applications/$package"
upload_api="https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/$package"

work="$(mktemp -d "${TMPDIR:-/tmp}/alex-play.XXXXXX")"
trap 'rm -rf "$work"' EXIT HUP INT TERM

b64url() {
	openssl base64 -A | tr '+/' '-_' | tr -d '='
}

# A signed JWT exchanged for an access token (Google's service-account OAuth flow).
jq -r .private_key "$key_file" > "$work/key.pem"
email="$(jq -r .client_email "$key_file")"
now="$(date +%s)"
header="$(printf '{"alg":"RS256","typ":"JWT"}' | b64url)"
claims="$(jq -cn --arg iss "$email" --argjson iat "$now" '{iss: $iss,
	scope: "https://www.googleapis.com/auth/androidpublisher", aud: "https://oauth2.googleapis.com/token",
	iat: $iat, exp: ($iat + 600)}' | b64url)"
signature="$(printf '%s.%s' "$header" "$claims" | openssl dgst -sha256 -sign "$work/key.pem" -binary | b64url)"
token="$(curl -fsS https://oauth2.googleapis.com/token \
	--data-urlencode 'grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer' \
	--data-urlencode "assertion=$header.$claims.$signature" | jq -r .access_token)"

call() {
	local response
	if ! response="$(curl -sS -w '\n%{http_code}' -H "Authorization: Bearer $token" "$@")"; then
		printf 'play: the request failed\n' >&2
		exit 1
	fi
	local code="${response##*$'\n'}"
	local body="${response%$'\n'*}"
	if [[ "$code" != 2* ]]; then
		printf 'play: HTTP %s\n%s\n' "$code" "$body" >&2
		exit 1
	fi
	printf '%s' "$body"
}

edit="$(call -X POST "$api/edits" | jq -r .id)"
printf 'play: uploading %s\n' "$aab"
version_code="$(call -X POST -H 'Content-Type: application/octet-stream' --data-binary "@$aab" \
	"$upload_api/edits/$edit/bundles?uploadType=media" | jq -r .versionCode)"
release_name="$version_name ($version_code)"
for track in $tracks; do
	body="$(jq -cn --arg track "$track" --arg name "$release_name" --arg code "$version_code" --arg status "$status" \
		'{track: $track, releases: [{name: $name, versionCodes: [$code], status: $status}]}')"
	call -X PUT -H 'Content-Type: application/json' --data "$body" "$api/edits/$edit/tracks/$track" > /dev/null
done

call -X POST "$api/edits/$edit:commit" > /dev/null
printf 'play: version code %s is on the %s tracks as %s (%s)\n' "$version_code" "$tracks" "$release_name" "$status"

# Production, in an edit of its own, so a refusal leaves the testing tracks in place. Play refuses until the
# account has production access, which a personal account earns with a closed test (docs/releases.md). From
# then on every release reaches production with no other change. PLAY_PRODUCTION=skip leaves it out.
if [[ "${PLAY_PRODUCTION:-try}" == "try" ]]; then
	if (
		prod="$(call -X POST "$api/edits" | jq -r .id)" || exit 1
		body="$(jq -cn --arg name "$release_name" --arg code "$version_code" --arg status "$status" \
			'{track: "production", releases: [{name: $name, versionCodes: [$code], status: $status}]}')"
		call -X PUT -H 'Content-Type: application/json' --data "$body" "$api/edits/$prod/tracks/production" > /dev/null || exit 1
		call -X POST "$api/edits/$prod:commit" > /dev/null || exit 1
	) 2> "$work/production.log"; then
		printf 'play: version code %s is on the production track\n' "$version_code"
	else
		printf 'play: production refused version code %s, so it stays on the testing tracks:\n' "$version_code"
		sed 's/^/  /' "$work/production.log" | head -12
		if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
			echo "::warning::Google Play refused production. The release is on the testing tracks."
		fi
	fi
fi

# The store listing and its images, from store/play/, in an edit of its own after the bundle, so a bad listing
# never holds a build back from testers. A failure here still fails the job. The API has no Chromebook image
# type, so that set was uploaded once in Play Console.
store="$(cd "$(dirname "$0")/.." && pwd)/store/play"
language="$(jq -r .language "$store/listing.json")"
listing_edit="$(call -X POST "$api/edits" | jq -r .id)"
listing="$(jq -c --rawfile d "$store/description.txt" '{language, title, shortDescription: .short_description,
	fullDescription: ($d | rtrimstr("\n"))}' "$store/listing.json")"
call -X PUT -H 'Content-Type: application/json' --data "$listing" \
	"$api/edits/$listing_edit/listings/$language" > /dev/null
# upload_images <image type> <file>...: replace every image of that type.
upload_images() {
	local type="$1" file
	shift
	call -X DELETE "$api/edits/$listing_edit/listings/$language/$type" > /dev/null
	for file in "$@"; do
		call -X POST -H 'Content-Type: image/png' --data-binary "@$file" \
			"$upload_api/edits/$listing_edit/listings/$language/$type?uploadType=media" > /dev/null
	done
}
upload_images icon "$store/icon-512.png"
upload_images featureGraphic "$store/feature-1024x500.png"
for type in phoneScreenshots sevenInchScreenshots tenInchScreenshots; do
	upload_images "$type" "$store"/screenshot-*.png
done
call -X POST "$api/edits/$listing_edit:commit" > /dev/null
printf 'play: listing and images set from store/play/\n'
