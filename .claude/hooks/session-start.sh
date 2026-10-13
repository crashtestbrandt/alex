#!/usr/bin/env bash
# SessionStart hook for Claude Code on the web. Installs the Godot 4.7 editor binary (headless Linux) and
# `just`, which every gate shells out to. No-op outside the web environment; locally the toolchain is
# installed by hand (docs/dev-setup.md). Idempotent: re-running skips what is already installed.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

GODOT_VERSION="4.7.2-stable"
JUST_VERSION="1.42.4"

PREFIX="$HOME/.local"
BIN_DIR="$PREFIX/bin"
mkdir -p "$BIN_DIR"
export PATH="$BIN_DIR:$PATH"

log() { printf '[session-start] %s\n' "$*"; }

if godot --version 2>/dev/null | grep -q '^4\.7\.'; then
  log "Godot $(godot --version) already installed."
else
  log "Installing Godot ${GODOT_VERSION}..."
  GODOT_ZIP="Godot_v${GODOT_VERSION}_linux.x86_64.zip"
  GODOT_URL="https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}/${GODOT_ZIP}"
  tmp="$(mktemp -d)"
  curl -fsSL "$GODOT_URL" -o "$tmp/godot.zip"
  unzip -q -o "$tmp/godot.zip" -d "$tmp"
  install -m 0755 "$tmp/Godot_v${GODOT_VERSION}_linux.x86_64" "$BIN_DIR/godot"
  rm -rf "$tmp"
  log "Godot installed: $(godot --version)"
fi

if command -v just >/dev/null 2>&1; then
  log "just $(just --version) already installed."
else
  log "Installing just ${JUST_VERSION}..."
  JUST_TGZ="just-${JUST_VERSION}-x86_64-unknown-linux-musl.tar.gz"
  JUST_URL="https://github.com/casey/just/releases/download/${JUST_VERSION}/${JUST_TGZ}"
  tmp="$(mktemp -d)"
  curl -fsSL "$JUST_URL" -o "$tmp/just.tar.gz"
  tar -xzf "$tmp/just.tar.gz" -C "$tmp" just
  install -m 0755 "$tmp/just" "$BIN_DIR/just"
  rm -rf "$tmp"
  log "just installed: $(just --version)"
fi

echo "export PATH=\"$BIN_DIR:\$PATH\"" >> "$HOME/.bashrc" 2>/dev/null || true
log "Toolchain ready."
