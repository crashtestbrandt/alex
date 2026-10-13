extends RefCounted
class_name NlaStage
## The six stages of Natural Language Acquisition (Blanc), plus UNKNOWN for a profile nobody has staged yet.
## A gestalt carries the stage it models; a profile carries the stage the child is working in. The stage never
## gates what the child can see. It tells the adults what to model next (docs/design.md).

enum Stage {
	UNKNOWN = 0,
	ECHOLALIA = 1,         ## whole gestalts, used as they were heard
	MITIGATION = 2,        ## chunks of gestalts mixed and matched
	SINGLE_WORDS = 3,      ## single words and two-word combinations
	EARLY_GRAMMAR = 4,     ## first original sentences, grammar still rough
	COMPLEX_GRAMMAR = 5,   ## more complex grammar
	FULL_GRAMMAR = 6,      ## complete, flexible sentences
}

const _LABELS: Dictionary[int, String] = {
	Stage.UNKNOWN: "Not staged",
	Stage.ECHOLALIA: "Stage 1 · Whole gestalts",
	Stage.MITIGATION: "Stage 2 · Mixing chunks",
	Stage.SINGLE_WORDS: "Stage 3 · Single words",
	Stage.EARLY_GRAMMAR: "Stage 4 · First sentences",
	Stage.COMPLEX_GRAMMAR: "Stage 5 · Complex grammar",
	Stage.FULL_GRAMMAR: "Stage 6 · Full grammar",
}

## The adult-facing label for `stage`.
static func label(stage: Stage) -> String:
	return _LABELS.get(stage, _LABELS[Stage.UNKNOWN])

## `value` as a Stage, or UNKNOWN for anything outside 1 to 6. Accepts an int or a numeric string, which is
## what a JSON file or a form hands back.
static func from_value(value: Variant) -> Stage:
	var n: int = JsonValue.to_int(value, -1)
	if n >= Stage.ECHOLALIA and n <= Stage.FULL_GRAMMAR:
		return n as Stage
	return Stage.UNKNOWN
