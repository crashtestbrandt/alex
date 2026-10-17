#!/usr/bin/env bash
# The App Store listing through the App Store Connect API: tools/app-store.sh <command>.
#
#   status               Print the app record, its versions and their states. Changes nothing.
#   get <path>           Print one API resource, such as /v1/apps. Changes nothing.
#   metadata X.Y.Z       Set the listing from store/app-store/metadata.json and description.txt. The version
#                        App Store Connect still lets us edit is renamed X.Y.Z, or one is made.
#   age-rating           Set the age rating and Kids band from store/app-store/age-rating.json.
#   screenshots X.Y.Z    Replace the iPhone and iPad screenshot sets with store/app-store/{iphone,ipad}/.
#   submit X.Y.Z [n]     Attach build n of X.Y.Z once processed, or the newest processed build, and send the
#                        version to App Review. The review contact comes from an earlier version, or from
#                        APP_REVIEW_PHONE and metadata.json when none has one.
#   supersede X.Y.Z      Withdraw any other version from review, so X.Y.Z can take its place.
#   release X.Y.Z n      All of it for a version tag: supersede, metadata, age-rating, screenshots, submit.
#                        An approved version goes live without a further step.
#
# It needs ASC_KEY_PATH, ASC_KEY_ID and ASC_ISSUER_ID, the same API key tools/testflight.sh uses
# (docs/releases.md). It talks to the API with curl, openssl and jq, so the key reaches no third-party code.
set -euo pipefail

for var in ASC_KEY_PATH ASC_KEY_ID ASC_ISSUER_ID; do
	if [[ -z "${!var:-}" ]]; then
		printf 'app-store: %s is not set\n' "$var" >&2
		exit 2
	fi
done
if [[ $# -lt 1 ]]; then
	sed -n '2,/^set -euo/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//' >&2
	exit 2
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLE_ID="io.github.crashtestbrandt.alex"
API="https://api.appstoreconnect.apple.com"

b64url() {
	openssl base64 -A | tr '+/' '-_' | tr -d '='
}

# An ES256 JWT. openssl signs in DER, and JWT wants r and s as two 32-byte big-endian numbers.
token() {
	local now header claims der r s
	now="$(date +%s)"
	header="$(jq -cn --arg kid "$ASC_KEY_ID" '{alg: "ES256", kid: $kid, typ: "JWT"}' | b64url)"
	claims="$(jq -cn --arg iss "$ASC_ISSUER_ID" --argjson iat "$now" \
		'{iss: $iss, iat: $iat, exp: ($iat + 1200), aud: "appstoreconnect-v1"}' | b64url)"
	der="$(printf '%s.%s' "$header" "$claims" | openssl dgst -sha256 -sign "$ASC_KEY_PATH" | openssl asn1parse -inform DER)"
	r="$(sed -n '2s/.*INTEGER *://p' <<< "$der")"
	s="$(sed -n '3s/.*INTEGER *://p' <<< "$der")"
	r="$(printf '%064s' "${r: -64}" | tr ' ' 0)"
	s="$(printf '%064s' "${s: -64}" | tr ' ' 0)"
	printf '%s.%s.%s' "$header" "$claims" "$(printf '%s%s' "$r" "$s" | xxd -r -p | b64url)"
}
JWT="$(token)"

# api <method> <path> [json body]: the response body, or the error and exit 1.
api() {
	local method="$1" path="$2" response code body
	local args=(-sS -X "$method" -H "Authorization: Bearer $JWT" -w '\n%{http_code}')
	if [[ $# -ge 3 ]]; then
		args+=(-H 'Content-Type: application/json' --data "$3")
	fi
	response="$(curl "${args[@]}" "$API$path")"
	code="${response##*$'\n'}"
	body="${response%$'\n'*}"
	if [[ "$code" != 2* ]]; then
		printf 'app-store: %s %s answered HTTP %s\n' "$method" "$path" "$code" >&2
		jq -r '.errors[]? | "  \(.title): \(.detail)"' <<< "$body" >&2 2> /dev/null || printf '%s\n' "$body" >&2
		exit 1
	fi
	printf '%s' "$body"
}

# The app's id. A caller's `id="$(app_id)"` stops the script, under set -e, when there is no record.
app_id() {
	local id
	id="$(api GET "/v1/apps?filter%5BbundleId%5D=$BUNDLE_ID" | jq -r '.data[0].id // empty')"
	if [[ -z "$id" ]]; then
		printf 'app-store: no App Store Connect app record for %s\n' "$BUNDLE_ID" >&2
		return 1
	fi
	printf '%s' "$id"
}

META="$ROOT/store/app-store/metadata.json"
meta() {
	jq -r "$1" "$META"
}

# The id of the version App Store Connect still lets us edit, renamed to $1, or a new one.
editable_version() {
	local id="$1" version="$2" vid current
	read -r vid current < <(api GET "/v1/apps/$id/appStoreVersions?filter%5Bplatform%5D=IOS" | jq -r '
		[.data[] | select(.attributes.appStoreState as $s
			| ["PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED"] | index($s))]
		| first | if . then "\(.id) \(.attributes.versionString)" else "" end')
	if [[ -z "${vid:-}" ]]; then
		api POST /v1/appStoreVersions "$(jq -cn --arg app "$id" --arg v "$version" '{data: {type: "appStoreVersions",
			attributes: {platform: "IOS", versionString: $v}, relationships: {app: {data: {type: "apps", id: $app}}}}}')" \
			| jq -r .data.id
		return
	fi
	if [[ "$current" != "$version" ]]; then
		api PATCH "/v1/appStoreVersions/$vid" "$(jq -cn --arg id "$vid" --arg v "$version" \
			'{data: {type: "appStoreVersions", id: $id, attributes: {versionString: $v}}}')" > /dev/null
		printf 'app-store: version %s is now %s\n' "$current" "$version" >&2
	fi
	printf '%s' "$vid"
}

# The app info App Store Connect still lets us edit.
editable_app_info() {
	api GET "/v1/apps/$1/appInfos" | jq -r '[.data[] | select((.attributes.state // .attributes.appStoreState)
		| test("PREPARE_FOR_SUBMISSION|DEVELOPER_REJECTED|REJECTED|WAITING_FOR_REVIEW|READY_FOR_DISTRIBUTION|READY_FOR_SALE") )]
		| sort_by(.attributes.state != "PREPARE_FOR_SUBMISSION") | first | .id // empty'
}

# The version's localization for the metadata locale, created when missing.
version_localization() {
	local vid="$1" locale lid
	locale="$(meta .locale)"
	lid="$(api GET "/v1/appStoreVersions/$vid/appStoreVersionLocalizations" \
		| jq -r --arg l "$locale" '.data[] | select(.attributes.locale == $l) | .id')"
	if [[ -z "$lid" ]]; then
		lid="$(api POST /v1/appStoreVersionLocalizations "$(jq -cn --arg v "$vid" --arg l "$locale" \
			'{data: {type: "appStoreVersionLocalizations", attributes: {locale: $l},
			relationships: {appStoreVersion: {data: {type: "appStoreVersions", id: $v}}}}}')" | jq -r .data.id)"
	fi
	printf '%s' "$lid"
}

cmd_metadata() {
	local version="$1" id vid lid aid ailid
	id="$(app_id)"
	vid="$(editable_version "$id" "$version")"
	api PATCH "/v1/appStoreVersions/$vid" "$(jq -cn --arg id "$vid" --arg c "$(meta .copyright)" \
		'{data: {type: "appStoreVersions", id: $id, attributes: {copyright: $c, releaseType: "AFTER_APPROVAL"}}}')" > /dev/null
	lid="$(version_localization "$vid")"
	api PATCH "/v1/appStoreVersionLocalizations/$lid" "$(jq -cn --arg id "$lid" \
		--rawfile d "$ROOT/store/app-store/description.txt" --slurpfile m "$META" '{data: {
			type: "appStoreVersionLocalizations", id: $id, attributes: {description: ($d | rtrimstr("\n")),
			keywords: $m[0].keywords, promotionalText: $m[0].promotional_text, supportUrl: $m[0].support_url,
			marketingUrl: $m[0].marketing_url}}}')" > /dev/null
	aid="$(editable_app_info "$id")"
	ailid="$(api GET "/v1/appInfos/$aid/appInfoLocalizations" \
		| jq -r --arg l "$(meta .locale)" '.data[] | select(.attributes.locale == $l) | .id')"
	api PATCH "/v1/appInfoLocalizations/$ailid" "$(jq -cn --arg id "$ailid" --slurpfile m "$META" '{data: {
		type: "appInfoLocalizations", id: $id, attributes: {name: $m[0].name, subtitle: $m[0].subtitle,
		privacyPolicyUrl: $m[0].privacy_policy_url}}}')" > /dev/null
	api PATCH "/v1/appInfos/$aid" "$(jq -cn --arg id "$aid" --arg c "$(meta .primary_category)" '{data: {
		type: "appInfos", id: $id, relationships: {primaryCategory: {data: {type: "appCategories", id: $c}}}}}')" > /dev/null
	api PATCH "/v1/apps/$id" "$(jq -cn --arg id "$id" '{data: {type: "apps", id: $id,
		attributes: {contentRightsDeclaration: "DOES_NOT_USE_THIRD_PARTY_CONTENT"}}}')" > /dev/null
	printf 'app-store: %s metadata set from store/app-store/\n' "$version"
}

cmd_age_rating() {
	local id aid did
	id="$(app_id)"
	aid="$(editable_app_info "$id")"
	did="$(api GET "/v1/appInfos/$aid/ageRatingDeclaration" | jq -r .data.id)"
	api PATCH "/v1/ageRatingDeclarations/$did" "$(jq -cn --arg id "$did" \
		--slurpfile a "$ROOT/store/app-store/age-rating.json" \
		'{data: {type: "ageRatingDeclarations", id: $id, attributes: $a[0]}}')" > /dev/null
	printf 'app-store: age rating set from store/app-store/age-rating.json\n'
}

# upload_screenshot <set id> <file>: reserve, send the parts App Store Connect asks for, then commit.
upload_screenshot() {
	local set_id="$1" file="$2" size reserved shot_id ops count i method url offset length headers checksum
	size="$(wc -c < "$file" | tr -d ' ')"
	reserved="$(api POST /v1/appScreenshots "$(jq -cn --arg s "$set_id" --arg n "$(basename "$file")" \
		--argjson z "$size" '{data: {type: "appScreenshots", attributes: {fileName: $n, fileSize: $z},
		relationships: {appScreenshotSet: {data: {type: "appScreenshotSets", id: $s}}}}}')")"
	shot_id="$(jq -r .data.id <<< "$reserved")"
	ops="$(jq -c '.data.attributes.uploadOperations' <<< "$reserved")"
	count="$(jq length <<< "$ops")"
	for ((i = 0; i < count; i++)); do
		method="$(jq -r ".[$i].method" <<< "$ops")"
		url="$(jq -r ".[$i].url" <<< "$ops")"
		offset="$(jq -r ".[$i].offset" <<< "$ops")"
		length="$(jq -r ".[$i].length" <<< "$ops")"
		headers=()
		while IFS= read -r header; do
			headers+=(-H "$header")
		done < <(jq -r ".[$i].requestHeaders[] | \"\(.name): \(.value)\"" <<< "$ops")
		tail -c +"$((offset + 1))" "$file" | head -c "$length" \
			| curl -fsS -X "$method" ${headers[@]+"${headers[@]}"} --data-binary @- "$url" > /dev/null
	done
	checksum="$(openssl dgst -md5 -r "$file" | cut -d' ' -f1)"
	api PATCH "/v1/appScreenshots/$shot_id" "$(jq -cn --arg id "$shot_id" --arg c "$checksum" '{data: {
		type: "appScreenshots", id: $id, attributes: {uploaded: true, sourceFileChecksum: $c}}}')" > /dev/null
	printf '%s' "$shot_id"
}

# Each store/app-store/<folder>/ is one screenshot set, replaced whole.
SHOT_FOLDERS=(iphone ipad)
SHOT_TYPES=(APP_IPHONE_61 APP_IPAD_PRO_3GEN_129)

cmd_screenshots() {
	local version="$1" id vid lid sets i set_id shot file shot_id
	id="$(app_id)"
	vid="$(editable_version "$id" "$version")"
	lid="$(version_localization "$vid")"
	sets="$(api GET "/v1/appStoreVersionLocalizations/$lid/appScreenshotSets")"
	for i in "${!SHOT_FOLDERS[@]}"; do
		set_id="$(jq -r --arg t "${SHOT_TYPES[$i]}" '.data[] | select(.attributes.screenshotDisplayType == $t) | .id' <<< "$sets")"
		if [[ -z "$set_id" ]]; then
			set_id="$(api POST /v1/appScreenshotSets "$(jq -cn --arg l "$lid" --arg t "${SHOT_TYPES[$i]}" '{data: {
				type: "appScreenshotSets", attributes: {screenshotDisplayType: $t}, relationships: {
				appStoreVersionLocalization: {data: {type: "appStoreVersionLocalizations", id: $l}}}}}')" | jq -r .data.id)"
		fi
		for shot in $(api GET "/v1/appScreenshotSets/$set_id/appScreenshots" | jq -r '.data[].id'); do
			api DELETE "/v1/appScreenshots/$shot" > /dev/null
		done
		for file in "$ROOT/store/app-store/${SHOT_FOLDERS[$i]}"/screenshot-*.png; do
			shot_id="$(upload_screenshot "$set_id" "$file")"
			printf 'app-store: %s %s uploaded as %s\n' "${SHOT_TYPES[$i]}" "$(basename "$file")" "$shot_id"
		done
	done
}

# wait_for_build <app id> <version> <build number>: the id of the lowest processed build of the version numbered
# at least <build number>. A release passes its commit's first number, the commit count times 100. A candidate
# on the same commit holds a lower number than the final, so a final tag takes the candidate's build, the one
# testers had (docs/releases.md "Build numbers").
# Processing takes 10 to 30 minutes after an upload; this polls each minute for up to 90.
wait_for_build() {
	local id="$1" version="$2" number="$3" i builds bid state
	for ((i = 0; i < 90; i++)); do
		builds="$(api GET "/v1/builds?filter%5Bapp%5D=$id&filter%5BpreReleaseVersion.version%5D=$version&limit=50" \
			| jq -c --argjson n "$number" '[.data[] | select((.attributes.version | tonumber) >= $n)
				| {id, number: (.attributes.version | tonumber), state: .attributes.processingState}] | sort_by(.number)')"
		bid="$(jq -r '[.[] | select(.state == "VALID")] | first | .id // empty' <<< "$builds")"
		if [[ -n "$bid" ]]; then
			printf '%s' "$bid"
			return 0
		fi
		state="$(jq -r 'if length == 0 then "not listed yet" else map("\(.number) \(.state)") | join(", ") end' <<< "$builds")"
		if jq -e 'length > 0 and all(.state == "FAILED" or .state == "INVALID")' <<< "$builds" > /dev/null; then
			printf 'app-store: no usable build of %s from %s on: %s\n' "$version" "$number" "$state" >&2
			return 1
		fi
		printf 'app-store: waiting for build %s of %s (%s)\n' "$number" "$version" "$state" >&2
		sleep 60
	done
	printf 'app-store: build %s of %s was not processed within 90 minutes\n' "$number" "$version" >&2
	return 1
}

# The review contact of an earlier version, as attributes for a new review detail. App Store Connect keeps one
# per version, and a new version starts with none.
earlier_review_contact() {
	local id="$1" vid="$2" other attributes
	for other in $(api GET "/v1/apps/$id/appStoreVersions?filter%5Bplatform%5D=IOS" | jq -r --arg v "$vid" '.data[] | select(.id != $v) | .id'); do
		attributes="$(api GET "/v1/appStoreVersions/$other/appStoreReviewDetail" 2> /dev/null \
			| jq -c '.data.attributes // empty | select(.contactPhone != null)
				| {contactFirstName, contactLastName, contactEmail, contactPhone}' || true)"
		if [[ -n "$attributes" ]]; then
			printf '%s' "$attributes"
			return 0
		fi
	done
	return 1
}

# submit X.Y.Z [build number]: with a build number, wait for that build; without, take the newest processed one.
cmd_submit() {
	local version="$1" number="${2:-}" id vid bid detail did sid contact
	id="$(app_id)"
	vid="$(editable_version "$id" "$version")"
	if [[ -n "$number" ]]; then
		bid="$(wait_for_build "$id" "$version" "$number")"
	else
		bid="$(api GET "/v1/builds?filter%5Bapp%5D=$id&filter%5BpreReleaseVersion.version%5D=$version&filter%5BprocessingState%5D=VALID&sort=-uploadedDate&limit=1" \
			| jq -r '.data[0].id // empty')"
	fi
	if [[ -z "$bid" ]]; then
		printf 'app-store: no processed build of %s. Upload one with a v%s tag first.\n' "$version" "$version" >&2
		exit 1
	fi
	api PATCH "/v1/appStoreVersions/$vid/relationships/build" "$(jq -cn --arg b "$bid" \
		'{data: {type: "builds", id: $b}}')" > /dev/null
	printf 'app-store: build %s attached to %s\n' "$bid" "$version"

	detail="$(api GET "/v1/appStoreVersions/$vid/appStoreReviewDetail" 2> /dev/null || printf '{}')"
	did="$(jq -r '.data.id // empty' <<< "$detail")"
	if [[ -n "$did" ]]; then
		api PATCH "/v1/appStoreReviewDetails/$did" "$(jq -cn --arg id "$did" --slurpfile m "$META" '{data: {
			type: "appStoreReviewDetails", id: $id, attributes: {notes: $m[0].review_notes}}}')" > /dev/null
	else
		if [[ -n "${APP_REVIEW_PHONE:-}" ]]; then
			contact="$(jq -cn --arg p "$APP_REVIEW_PHONE" --slurpfile m "$META" '{
				contactFirstName: $m[0].review_contact.first_name, contactLastName: $m[0].review_contact.last_name,
				contactEmail: $m[0].review_contact.email, contactPhone: $p}')"
		elif ! contact="$(earlier_review_contact "$id" "$vid")"; then
			printf 'app-store: no earlier version has a review contact. Set APP_REVIEW_PHONE, the number App Review may call.\n' >&2
			exit 2
		fi
		api POST /v1/appStoreReviewDetails "$(jq -cn --arg v "$vid" --argjson c "$contact" --slurpfile m "$META" '{data: {
			type: "appStoreReviewDetails", attributes: ($c + {demoAccountRequired: false, notes: $m[0].review_notes}),
			relationships: {appStoreVersion: {data: {type: "appStoreVersions", id: $v}}}}}')" > /dev/null
	fi

	sid="$(api GET "/v1/reviewSubmissions?filter%5Bapp%5D=$id&filter%5Bplatform%5D=IOS&filter%5Bstate%5D=READY_FOR_REVIEW" \
		| jq -r '.data[0].id // empty')"
	if [[ -z "$sid" ]]; then
		sid="$(api POST /v1/reviewSubmissions "$(jq -cn --arg a "$id" '{data: {type: "reviewSubmissions",
			attributes: {platform: "IOS"}, relationships: {app: {data: {type: "apps", id: $a}}}}}')" | jq -r .data.id)"
	fi
	# A submission left open by an earlier run may hold other items, or none for this version.
	if ! api GET "/v1/reviewSubmissions/$sid/items?include=appStoreVersion" \
		| jq -e --arg v "$vid" 'any(.data[]; .relationships.appStoreVersion.data.id? == $v)' > /dev/null; then
		api POST /v1/reviewSubmissionItems "$(jq -cn --arg s "$sid" --arg v "$vid" '{data: {type: "reviewSubmissionItems",
			relationships: {reviewSubmission: {data: {type: "reviewSubmissions", id: $s}},
			appStoreVersion: {data: {type: "appStoreVersions", id: $v}}}}}')" > /dev/null
	fi
	api PATCH "/v1/reviewSubmissions/$sid" "$(jq -cn --arg id "$sid" '{data: {type: "reviewSubmissions", id: $id,
		attributes: {submitted: true}}}')" > /dev/null
	printf 'app-store: %s sent to App Review\n' "$version"
}

# Withdraw any other version from review. App Store Connect keeps one version in progress, so a newer tag
# replaces a version still waiting. The withdrawn version becomes editable and is renamed to this one.
cmd_supersede() {
	local version="$1" id sid other i waiting
	id="$(app_id)"
	for sid in $(api GET "/v1/reviewSubmissions?filter%5Bapp%5D=$id&filter%5Bplatform%5D=IOS&filter%5Bstate%5D=WAITING_FOR_REVIEW,IN_REVIEW,UNRESOLVED_ISSUES" \
		| jq -r '.data[].id'); do
		other="$(api GET "/v1/reviewSubmissions/$sid/items?include=appStoreVersion" \
			| jq -r '[.included[]? | select(.type == "appStoreVersions") | .attributes.versionString] | first // ""')"
		if [[ "$other" == "$version" ]]; then
			continue
		fi
		api PATCH "/v1/reviewSubmissions/$sid" "$(jq -cn --arg id "$sid" '{data: {type: "reviewSubmissions",
			id: $id, attributes: {canceled: true}}}')" > /dev/null
		printf 'app-store: withdrew %s from review, for %s\n' "${other:-a submission}" "$version"
		# Withdrawing takes a moment, and the version is not editable until it finishes.
		for ((i = 0; i < 30; i++)); do
			waiting="$(api GET "/v1/reviewSubmissions/$sid" | jq -r '.data.attributes.state')"
			[[ "$waiting" == "CANCELING" ]] || break
			sleep 10
		done
	done
}

# release X.Y.Z <build number>: everything a version tag does on the App Store, in order.
cmd_release() {
	local version="$1" number="$2" id state
	id="$(app_id)"
	# A re-run of the same tag finds its version already submitted, in review or released, and stops there.
	state="$(api GET "/v1/apps/$id/appStoreVersions?filter%5Bplatform%5D=IOS&filter%5BversionString%5D=$version" \
		| jq -r '.data[0].attributes.appStoreState // ""')"
	case "$state" in
		"" | PREPARE_FOR_SUBMISSION | DEVELOPER_REJECTED | REJECTED | METADATA_REJECTED) ;;
		*)
			printf 'app-store: %s is already %s\n' "$version" "$state"
			return 0
			;;
	esac
	cmd_supersede "$version"
	cmd_metadata "$version"
	cmd_age_rating
	cmd_screenshots "$version"
	cmd_submit "$version" "$number"
}

cmd_status() {
	local id
	id="$(app_id)"
	api GET "/v1/apps/$id" | jq -r '.data.attributes | "app: \(.name) (\(.bundleId)), primary locale \(.primaryLocale)"'
	api GET "/v1/apps/$id/appInfos" | jq -r '.data[] | "app info \(.id): \(.attributes.state // .attributes.appStoreState)"'
	api GET "/v1/apps/$id/appStoreVersions" \
		| jq -r '.data[] | "version \(.attributes.versionString) [\(.attributes.platform)]: \(.attributes.appStoreState // .attributes.appVersionState)"'
}

case "$1" in
	status) cmd_status ;;
	get) api GET "$2" | jq . ;;
	metadata) cmd_metadata "${2:?usage: tools/app-store.sh metadata X.Y.Z}" ;;
	age-rating) cmd_age_rating ;;
	screenshots) cmd_screenshots "${2:?usage: tools/app-store.sh screenshots X.Y.Z}" ;;
	submit) cmd_submit "${2:?usage: tools/app-store.sh submit X.Y.Z [build number]}" "${3:-}" ;;
	supersede) cmd_supersede "${2:?usage: tools/app-store.sh supersede X.Y.Z}" ;;
	release) cmd_release "${2:?usage: tools/app-store.sh release X.Y.Z <build number>}" "${3:?usage: tools/app-store.sh release X.Y.Z <build number>}" ;;
	*)
		printf 'app-store: unknown command %s\n' "$1" >&2
		exit 2
		;;
esac
