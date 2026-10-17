class_name BuildStamp
## The release and build a copy of Alex is, as the profile picker shows it in a corner: "0.1.2 (34)", a
## candidate's "0.1.2-rc.1 (34)", a local export's "dev (34)", or "dev" from the editor.
##
## tools/export.sh stamps `alex/build/label` and `alex/build/number` into project.godot for the length of an
## export (docs/releases.md).

const LABEL_SETTING: String = "alex/build/label"
const NUMBER_SETTING: String = "alex/build/number"

## The stamp for this copy.
static func current() -> String:
	var label: String = ProjectSettings.get_setting(LABEL_SETTING, "dev")
	var number: int = ProjectSettings.get_setting(NUMBER_SETTING, 0)
	return text(label, number)

## A label and a build number as one stamp. A number of zero means no build, and the label stands alone.
static func text(label: String, number: int) -> String:
	var shown: String = label.strip_edges()
	if shown.is_empty():
		shown = "dev"
	if number <= 0:
		return shown
	return "%s (%d)" % [shown, number]
