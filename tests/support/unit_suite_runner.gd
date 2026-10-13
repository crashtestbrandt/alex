extends RefCounted
class_name UnitSuiteRunner
## Runs one [UnitTest] suite's test methods with its hooks, and measures what the suite left behind.
##
## The Node count is the hermeticity check. `Performance.OBJECT_ORPHAN_NODE_COUNT` is every engine Node alive
## outside a scene tree and `OBJECT_NODE_COUNT` every one inside; a suite runs with no tree of its own, so the
## two together are every Node in the process. A method that builds one and drops it leaves it alive, and the
## difference is what a suite declaring nothing is held to.

## The names of a suite's test methods, sorted.
static func test_methods(suite: UnitTest) -> Array[String]:
	var out: Array[String] = []
	for method_info: Dictionary in suite.get_method_list():
		var method_name: String = method_info.get("name", "")
		if method_name.begins_with("test_"):
			out.push_back(method_name)
	out.sort()
	return out

## Run every method in `methods` on `suite`, setup and teardown around each. Returns `checks` (int),
## `failures` (PackedStringArray), `nodes_left` (int) and `nodes_left_by` (Dictionary[String, int]).
static func run(suite: UnitTest, methods: Array[String]) -> Dictionary:
	var left_by: Dictionary[String, int] = {}
	var before_all: int = _nodes_alive()
	for method_name: String in methods:
		var before: int = _nodes_alive()
		suite.setup()
		suite.callv(method_name, [])
		suite.teardown()
		var rise: int = _nodes_alive() - before
		if rise > 0:
			left_by[method_name] = rise
	return {
		"checks": suite.check_count(),
		"failures": suite.failures(),
		"nodes_left": _nodes_alive() - before_all,
		"nodes_left_by": left_by,
	}

## Whether `needs` declares `flag`.
static func declares(needs: int, flag: int) -> bool:
	return (needs & flag) != 0

## The `Needs` flags named in a `--without=` argument ("nodes,scenes,servers,assets" or "all"), or -1 for a
## name the enum does not carry.
static func parse_without(spec: String) -> int:
	var mask: int = 0
	for raw: String in spec.split(",", false):
		var name: String = raw.strip_edges().to_upper()
		if name == "ALL":
			mask |= UnitTest.Needs.NODES | UnitTest.Needs.SCENES | UnitTest.Needs.SERVERS | UnitTest.Needs.ASSETS
		elif UnitTest.Needs.has(name) and UnitTest.Needs[name] != 0:
			mask |= UnitTest.Needs[name]
		else:
			return -1
	return mask

## The names of the `Needs` flags set in `mask`, for a report line; "pure" for none.
static func describe(mask: int) -> String:
	var names: PackedStringArray = PackedStringArray()
	for name: String in UnitTest.Needs.keys():
		var value: int = UnitTest.Needs[name]
		if value != 0 and (mask & value) != 0:
			names.push_back(name.to_lower())
	return "pure" if names.is_empty() else "+".join(names)

static func _nodes_alive() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) \
		+ int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
