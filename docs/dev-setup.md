# Dev setup

## Toolchain

- **Godot 4.7-stable.** Found through `GODOT_BIN`, then `godot` or `godot4` on PATH, then
  `/Applications/Godot.app` on macOS (`tools/godot-bin.sh`). Homebrew's cask puts a `godot` on PATH.
- **just**, the command runner. `just` with no argument lists every recipe.
- **git-lfs**, for any binary media the repository ships (`.gitattributes`). Nothing is tracked yet.
- **For exports:** export templates of the same Godot version, plus a JDK and an Android SDK for Android and
  Xcode for iOS (docs/exports.md "Machine setup").

```sh
just setup     # import pass; registers every class_name. Run once after cloning.
just editor
just run
just check
```

## After cloning

`just setup` is one import pass. Godot writes the global class cache only during an import, so a `--script`
gate run before it fails with "Could not find type UnitTest".

## Claude Code

`.claude/settings.json` runs `.claude/hooks/session-start.sh` on session start. In a cloud session it
installs Godot 4.7 and `just`; locally it does nothing.

`.mcp.json` runs the `godot-docs` MCP server through `bunx`. Pass `version: "4.7"` on every query.

## macOS note

Headless `--import` can crash inside MoltenVK. `tools/lint-gdscript.sh` runs the import on opengl3 and
treats it as best-effort on macOS; the project load pass still fails on every script error. Linux CI keeps
both passes fatal.
