#!/usr/bin/env bash
# Tag main with a version and push the tag: tools/release.sh X.Y.Z.
#
# `just release X.Y.Z` runs this (docs/releases.md). The pushed tag starts .github/workflows/release.yml,
# which builds every platform with that version. project.godot keeps a placeholder; the tag is the version.
set -euo pipefail

if [[ $# -ne 1 ]]; then
	printf 'usage: tools/release.sh X.Y.Z\n' >&2
	exit 2
fi
version="$1"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
	printf 'release: the version is "%s". It must be X.Y.Z.\n' "$version" >&2
	exit 2
fi
tag="v$version"

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
# iOS and Google Play refuse a version lower than one they already hold.
latest="$(git tag --list 'v*' | sed 's/^v//' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -1)"
if [[ -n "$latest" && "$(printf '%s\n%s\n' "$latest" "$version" | sort -V | tail -1)" != "$version" ]]; then
	printf 'release: %s is lower than the latest release, %s.\n' "$version" "$latest" >&2
	exit 1
fi

git tag -a "$tag" -m "Alex $version"
git push origin "$tag"
printf 'release: pushed %s, build %s. The release workflow is at\n' "$tag" "$(git rev-list --count HEAD)"
printf '  https://github.com/crashtestbrandt/alex/actions/workflows/release.yml\n'
