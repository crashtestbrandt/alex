#!/usr/bin/env bash
# Size caps for the two files that are maps rather than manuals.
#
# CLAUDE.md loads into every agent context on every session, and README.md is a human's first read. When
# this trips, move a section into docs/ and leave a one-line pointer. Raising a cap is the owner's call.
set -euo pipefail

cd "$(dirname "$0")/.."

LIMITS=(
	"CLAUDE.md:40000"
	"README.md:16000"
)

status=0
for entry in "${LIMITS[@]}"; do
	file="${entry%%:*}"
	max="${entry##*:}"
	if [ ! -f "$file" ]; then
		echo "::error file=$file::check-doc-size: $file is missing"
		status=1
		continue
	fi
	size="$(wc -c < "$file" | tr -d ' ')"
	pct=$(( size * 100 / max ))
	if [ "$size" -gt "$max" ]; then
		echo "::error file=$file::$file is $size bytes, over the $max limit. Move a section to docs/ and leave a pointer."
		status=1
	elif [ "$pct" -ge 90 ]; then
		printf '  WARN %-10s %6s / %6s bytes (%s%%)\n' "$file" "$size" "$max" "$pct"
	else
		printf '  ok   %-10s %6s / %6s bytes (%s%%)\n' "$file" "$size" "$max" "$pct"
	fi
done

if [ "$status" -ne 0 ]; then
	exit 1
fi
echo "Doc sizes OK."
