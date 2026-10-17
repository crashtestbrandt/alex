#!/usr/bin/env bash
# Tag main with a version and push the tag: tools/release.sh X.Y.Z, or X.Y.Z-rc.N for a release candidate.
#
# `just release` runs this (docs/releases.md). The pushed tag starts .github/workflows/release.yml, which
# builds every platform with that version. project.godot keeps a placeholder; the tag is the version. A release
# candidate goes to testers only.
#
# With the REQUIRE_CANDIDATE repository variable set to true, a final needs a candidate on its commit.
set -euo pipefail

if [[ $# -ne 1 ]]; then
	printf 'usage: tools/release.sh X.Y.Z | X.Y.Z-rc.N\n' >&2
	exit 2
fi
version="$1"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-rc\.[0-9]+)?$ ]]; then
	printf 'release: the version is "%s". It must be X.Y.Z or X.Y.Z-rc.N.\n' "$version" >&2
	exit 2
fi
tag="v$version"
# A candidate's number is the last two digits of its build number (docs/releases.md "Build numbers").
if [[ "$version" =~ -rc\.([0-9]+)$ ]] && (( 10#${BASH_REMATCH[1]} < 1 || 10#${BASH_REMATCH[1]} > 98 )); then
	printf 'release: a candidate is numbered 1 to 98, not %s.\n' "${BASH_REMATCH[1]}" >&2
	exit 2
fi

# order_key <version>: a key sort -V orders correctly. X.Y.Z-rc.N comes after X.Y.(Z-1) and before X.Y.Z.
order_key() {
	if [[ "$1" =~ ^([0-9]+\.[0-9]+\.[0-9]+)-rc\.([0-9]+)$ ]]; then
		printf '%s.0.%s' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
	else
		printf '%s.1.0' "$1"
	fi
}

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ "$(git rev-parse --abbrev-ref HEAD)" != "main" ]]; then
	printf 'release: check out main first.\n' >&2
	exit 1
fi
if [[ -n "$(git status --porcelain)" ]]; then
	printf 'release: commit or stash your changes first.\n' >&2
	exit 1
fi
git fetch --quiet --tags origin main
if [[ "$(git rev-parse HEAD)" != "$(git rev-parse origin/main)" ]]; then
	printf 'release: main is not the same as origin/main. Pull or push first.\n' >&2
	exit 1
fi
if git rev-parse --quiet --verify "refs/tags/$tag" > /dev/null; then
	printf 'release: %s already exists.\n' "$tag" >&2
	exit 1
fi
# A final ships what testers had: a candidate of the same version on this commit. The REQUIRE_CANDIDATE
# repository variable makes that a rule, which the release workflow checks again.
if [[ "$version" != *-rc.* ]] && ! git tag --points-at HEAD | grep -qx "v${version//./\\.}-rc\.[0-9][0-9]*"; then
	required="$(gh variable get REQUIRE_CANDIDATE 2> /dev/null || true)"
	if [[ "$required" == "true" ]]; then
		printf 'release: no candidate of %s is on this commit. Run just release %s-rc.1 first.\n' "$version" "$version" >&2
		exit 1
	fi
	printf 'release: no candidate of %s is on this commit, so the stores get a build no tester had.\n' "$version"
fi
# iOS and Google Play refuse a version lower than one they already hold. A candidate after its own final is
# refused too, because TestFlight closes a version once the App Store releases it.
latest=""
latest_key=""
while IFS= read -r existing; do
	key="$(order_key "$existing")"
	if [[ -z "$latest_key" || "$(printf '%s\n%s\n' "$latest_key" "$key" | sort -V | tail -1)" == "$key" ]]; then
		latest="$existing"
		latest_key="$key"
	fi
done < <(git tag --list 'v*' | sed 's/^v//' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+(-rc\.[0-9]+)?$' || true)
key="$(order_key "$version")"
if [[ -n "$latest" && "$(printf '%s\n%s\n' "$latest_key" "$key" | sort -V | tail -1)" != "$key" ]]; then
	printf 'release: %s comes before the latest release, %s.\n' "$version" "$latest" >&2
	exit 1
fi

git tag -a "$tag" -m "Alex $version"
git push origin "$tag"
printf 'release: pushed %s, build %s. The release workflow is at\n' "$tag" "$(git rev-list --count HEAD)"
printf '  https://github.com/crashtestbrandt/alex/actions/workflows/release.yml\n'
