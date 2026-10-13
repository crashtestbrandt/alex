extends SceneTree
## Load every script under tools/instr/, so a probe that cannot compile fails `just lint` rather than a run.
## Loading is the whole test; nothing is instantiated.

const _DIR: String = "res://tools/instr"

func _initialize() -> void:
	var failed: int = 0
	var checked: int = 0
	var dir: DirAccess = DirAccess.open(_DIR)
	if dir != null:
		for file: String in dir.get_files():
			if not file.ends_with(".gd"):
				continue
			checked += 1
			var script: GDScript = load("%s/%s" % [_DIR, file]) as GDScript
			if script == null or not script.can_instantiate():
				failed += 1
				print("INSTR-LINT FAIL %s does not compile (its parse error is above)" % file)
	print("INSTR-LINT checked %d instrumentation script(s), %d failed" % [checked, failed])
	quit(1 if failed > 0 else 0)
