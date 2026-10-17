extends SceneTree
## Pack probe: mount an exported .pck as res:// and check what a shipped build can read. Every starter pack
## and style preset loads, the privacy policy reads, and nothing from tests/, tools/ or docs/ shipped. tools/check-exports.sh runs it
## with `--main-pack <pck> --script <this file>`; tools/ never ships, so the script is read from disk. Prints
## PACK-PROBE PASS or FAIL and exits with the matching code.

## Paths that only a development checkout holds.
const _ABSENT: Array[String] = ["res://tests", "res://tools", "res://docs", "res://.mcp.json"]

var _failures: PackedStringArray = PackedStringArray()

func _initialize() -> void:
	var starters: Array[Starter] = Starter.list_all()
	var ids: PackedStringArray = PackedStringArray()
	for s: Starter in starters:
		ids.push_back(s.id)
	print("  starters: %s" % ", ".join(ids))
	_check(not starters.is_empty(), "the starter packs load")
	_check(ids.has("blank"), "the blank pack loads")

	var styles: PackedStringArray = StylePreset.list_ids()
	print("  styles: %s" % ", ".join(styles))
	_check(not styles.is_empty(), "the style presets are listed")
	for style_id: String in styles:
		_check(ResourceLoader.exists("%s/%s.tres" % [StylePreset.DIR, style_id]), "style %s loads" % style_id)

	var stamp: String = BuildStamp.current()
	print("  build stamp: %s" % stamp)
	_check(stamp != "dev", "the export stamped a build number")

	var policy: PackedStringArray = PolicyText.load_blocks()
	print("  privacy policy: %d blocks" % policy.size())
	_check(not policy.is_empty(), "the privacy policy reads")

	for path: String in _ABSENT:
		_check(not DirAccess.dir_exists_absolute(path) and not FileAccess.file_exists(path), "%s did not ship" % path)

	print("PACK-PROBE %s" % ("PASS" if _failures.is_empty() else "FAIL"))
	quit(0 if _failures.is_empty() else 1)

func _check(ok: bool, label: String) -> void:
	if not ok:
		_failures.push_back(label)
		print("  FAIL %s" % label)
