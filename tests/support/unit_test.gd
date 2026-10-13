extends RefCounted
class_name UnitTest
## Base class for the hand-rolled unit suites. A suite extends this and defines `test_*` methods; the runner
## (tests/run_unit_tests.gd) discovers suites under tests/unit/ and calls every `test_*` method by reflection.
## No scene tree, no physics, no windowing, so `just test` runs in about a second.
##
## Failures accumulate rather than abort, so one run reports every mismatch. A suite targets a pure function.
## Logic that genuinely needs a live scene belongs in a tools/instr/*_probe.gd gate.
##
## A suite declares what it needs through [method needs], and the runner checks the declaration: it counts the
## engine Nodes alive before and after every test method, and a suite that declared nothing and left one alive
## fails by name. [method setup] and [method teardown] run around every test method.

## What a suite needs beyond a script and plain data. Combined with `|`.
enum Needs {
	PURE = 0,      ## constructible from plain data: no Node, no scene, no server, no media asset
	NODES = 1,     ## builds engine Nodes and leaves them alive (a Node freed inside the method needs no flag)
	SCENES = 2,    ## loads or instantiates a .tscn
	SERVERS = 4,   ## touches PhysicsServer, RenderingServer, DisplayServer or the worker pool
	ASSETS = 8,    ## reads an imported media asset, which is a Git LFS object
}

var _failures: PackedStringArray = PackedStringArray()
var _checks: int = 0

## Override to declare what the suite needs (a `Needs` bitmask). The default declares nothing.
func needs() -> int:
	return Needs.PURE

## Runs before every test method. Override to build a fixture.
func setup() -> void:
	pass

## Runs after every test method, whether or not its checks passed. Override to free what setup built.
func teardown() -> void:
	pass

func failures() -> PackedStringArray:
	return _failures

func check_count() -> int:
	return _checks

func assert_true(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures.push_back(label)

func assert_false(ok: bool, label: String) -> void:
	assert_true(not ok, label)

func assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	_checks += 1
	if actual != expected:
		_failures.push_back("%s (expected %s, got %s)" % [label, expected, actual])

func assert_almost_eq(actual: float, expected: float, eps: float, label: String) -> void:
	_checks += 1
	if absf(actual - expected) > eps:
		_failures.push_back("%s (expected ~%s +/- %s, got %s)" % [label, expected, eps, actual])

func assert_null(value: Variant, label: String) -> void:
	_checks += 1
	if value != null:
		_failures.push_back("%s (expected null, got %s)" % [label, value])

func assert_not_null(value: Variant, label: String) -> void:
	_checks += 1
	if value == null:
		_failures.push_back("%s (expected a value, got null)" % label)
