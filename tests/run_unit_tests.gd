extends SceneTree
## Unit-test runner: discovers every `*_test.gd` suite under res://tests/unit/, loads it as a script (each
## suite extends [UnitTest]), calls every `test_*` method by reflection, and aggregates PASS/FAIL. Run via
## `just test`. Exits non-zero on any failure, or if no suites or no test methods are found.
##
## `--without=<needs>` after `--` skips every suite that declares one of the named `UnitTest.Needs` flags
## (`nodes`, `scenes`, `servers`, `assets`, or `all`). `just test-pure` passes `all`.

const _SUITE_DIR: String = "res://tests/unit"

func _initialize() -> void:
	var without: int = _without_mask()
	if without < 0:
		quit(2)
		return
	var suite_paths: PackedStringArray = _discover_suites()
	if suite_paths.is_empty():
		printerr("run_unit_tests: no *_test.gd suites found under %s" % _SUITE_DIR)
		quit(1)
		return

	var suite_count: int = 0
	var skipped: int = 0
	var total_checks: int = 0
	var total_failures: PackedStringArray = PackedStringArray()

	if without > 0:
		print("\n===== UNIT TESTS (%s, without %s) =====" % [_SUITE_DIR, UnitSuiteRunner.describe(without)])
	else:
		print("\n===== UNIT TESTS (%s) =====" % _SUITE_DIR)
	for path: String in suite_paths:
		var suite_name: String = path.get_file()
		var script: GDScript = load(path) as GDScript
		if script == null:
			total_failures.push_back("%s: failed to load as a GDScript" % suite_name)
			continue
		# A suite that does not compile is a failure, reported by name. `load()` hands back a GDScript for a
		# file with a parse error; calling `new()` on it raises and the runner never reaches `quit()`.
		if not script.can_instantiate():
			total_failures.push_back("%s: does not compile (its parse error is above)" % suite_name)
			print("  FAIL %s: does not compile (its parse error is above)" % suite_name)
			continue
		var instance: Variant = script.new()
		if not is_instance_of(instance, UnitTest):
			total_failures.push_back("%s: does not extend UnitTest" % suite_name)
			continue
		var suite: UnitTest = instance
		var needs: int = suite.needs()
		if (needs & without) != 0:
			skipped += 1
			continue
		var test_methods: Array[String] = UnitSuiteRunner.test_methods(suite)
		if test_methods.is_empty():
			total_failures.push_back("%s: no test_* methods found" % suite_name)
			continue
		suite_count += 1
		var result: Dictionary = UnitSuiteRunner.run(suite, test_methods)
		var checks: int = result["checks"]
		total_checks += checks
		var failures: PackedStringArray = result["failures"]
		for failure: String in failures:
			var line: String = "%s: %s" % [suite_name, failure]
			total_failures.push_back(line)
			print("  FAIL " + line)
		var nodes_left: int = result["nodes_left"]
		if nodes_left > 0 and not UnitSuiteRunner.declares(needs, UnitTest.Needs.NODES):
			var left_by: Dictionary[String, int] = result["nodes_left_by"]
			var line: String = "%s: declares no Needs.NODES but left %d Node(s) alive (%s)" % [
				suite_name, nodes_left, ", ".join(left_by.keys())]
			total_failures.push_back(line)
			print("  FAIL " + line)

	var verdict: String = "ALL PASS" if total_failures.is_empty() else "FAILURES"
	var skipped_note: String = "" if skipped == 0 else ", %d skipped" % skipped
	print("  %d suite(s)%s, %d check(s), %d failure(s) -- %s" % [
		suite_count, skipped_note, total_checks, total_failures.size(), verdict])
	print("===================================\n")
	quit(0 if total_failures.is_empty() else 1)

func _without_mask() -> int:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--without="):
			var spec: String = arg.substr("--without=".length())
			var mask: int = UnitSuiteRunner.parse_without(spec)
			if mask < 0:
				printerr("run_unit_tests: --without names a Needs flag that does not exist: %s" % spec)
			return mask
	return 0

func _discover_suites() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var dir: DirAccess = DirAccess.open(_SUITE_DIR)
	if dir == null:
		return out
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.ends_with("_test.gd"):
			out.push_back("%s/%s" % [_SUITE_DIR, entry])
		entry = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out
