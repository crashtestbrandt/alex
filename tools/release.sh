#!/usr/bin/env bash
# Tag main with the version in project.godot and push the tag: tools/release.sh.
#
# `just release` runs this (docs/releases.md). The pushed tag starts .github/workflows/release.yml. The version
# changes in a pull request first; this script only tags what main already holds.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

version="$(sed -n 's/^config\/version="\(.*\)"$/\1/p' project.godot)"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
	printf 'release: project.godot has version "%s". It must be X.Y.Z.\n' "$version" >&2
	exit 1
fi
tag="v$version"

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
	printf 'release: %s already exists. Raise application/config/version in a pull request first.\n' "$tag" >&2
	exit 1
fi

git tag -a "$tag" -m "Alex $version"
git push origin "$tag"
printf 'release: pushed %s, build %s. The release workflow is at\n' "$tag" "$(git rev-list --count HEAD)"
printf '  https://github.com/crashtestbrandt/alex/actions/workflows/release.yml\n'
