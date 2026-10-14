#!/usr/bin/env bash
# Upload an AAB to a Google Play track: tools/play-upload.sh <aab> <release name>.
#
# The release workflow runs this (docs/releases.md). It needs:
#
# - PLAY_SERVICE_ACCOUNT_JSON: the path to a Google Cloud service account key that Play Console has granted
#   release rights on the app.
# - PLAY_TRACK: the track, `internal` when unset.
# - PLAY_RELEASE_STATUS: `completed` when unset. An app Google has not reviewed yet takes only `draft`.
#
# It talks to the Play Developer API with curl, openssl and jq, so the key reaches no third-party code.
set -euo pipefail

if [[ $# -ne 2 || ! -f "$1" ]]; then
	printf 'usage: tools/play-upload.sh <aab> <release name>\n' >&2
	exit 2
fi
aab="$1"
release_name="$2"
key_file="${PLAY_SERVICE_ACCOUNT_JSON:?PLAY_SERVICE_ACCOUNT_JSON is not set}"
track="${PLAY_TRACK:-internal}"
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
body="$(jq -cn --arg track "$track" --arg name "$release_name" --arg code "$version_code" --arg status "$status" \
	'{track: $track, releases: [{name: $name, versionCodes: [$code], status: $status}]}')"
call -X PUT -H 'Content-Type: application/json' --data "$body" "$api/edits/$edit/tracks/$track" > /dev/null
call -X POST "$api/edits/$edit:commit" > /dev/null
printf 'play: version code %s is on the %s track as %s (%s)\n' "$version_code" "$track" "$release_name" "$status"
