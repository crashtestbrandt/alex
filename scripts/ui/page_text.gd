class_name PageText
## A page shipped beside the app, the privacy policy, the caregiver guide or the glossary, as plain text blocks
## for the profile picker. It reads the subset of Markdown that PRIVACY.md, GUIDE.md and GLOSSARY.md use:
##
## - The `#` title is dropped, because the picker's heading shows it.
## - A `##` heading becomes its own block.
## - A paragraph's lines join into one block.
## - A `- ` item becomes a block that starts with a bullet. Its indented lines join it.
## - A table's header and rule rows are dropped. Each other row becomes "first cell: second cell". A `\|` in
##   a cell is a bar, not a cell break.
## - `**bold**`, backticks and `[text](url)` links keep only their text.

const PRIVACY: String = "res://PRIVACY.md"
const GUIDE: String = "res://GUIDE.md"
const GLOSSARY: String = "res://GLOSSARY.md"
const BULLET: String = "• "

## The blocks of the page at `path`, or none when the file is missing.
static func load_blocks(path: String) -> PackedStringArray:
	if not FileAccess.file_exists(path):
		return PackedStringArray()
	return blocks(FileAccess.get_file_as_string(path))

## The section headings of the page at `path`, as [method blocks] writes them, so a caller can style them.
static func load_headings(path: String) -> PackedStringArray:
	if not FileAccess.file_exists(path):
		return PackedStringArray()
	return headings(FileAccess.get_file_as_string(path))

static func headings(markdown: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for raw: String in markdown.replace("\r\n", "\n").split("\n"):
		var line: String = raw.strip_edges()
		if line.begins_with("## "):
			out.push_back(_inline(line.trim_prefix("## ")))
	return out

static func blocks(markdown: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var current: String = ""
	var table_row: int = 0
	for raw: String in markdown.replace("\r\n", "\n").split("\n"):
		var line: String = raw.strip_edges()
		var continues: bool = raw.begins_with(" ") and not current.is_empty() and not line.is_empty()
		if continues and not line.begins_with("|") and not line.begins_with("- "):
			current += " " + line
			continue
		if not line.begins_with("|"):
			table_row = 0
		if not current.is_empty() and (line.is_empty() or line.begins_with("#") or line.begins_with("- ") or line.begins_with("|")):
			out.push_back(_inline(current))
			current = ""
		if line.is_empty() or line.begins_with("# "):
			continue
		if line.begins_with("## "):
			out.push_back(_inline(line.trim_prefix("## ")))
		elif line.begins_with("- "):
			current = BULLET + line.trim_prefix("- ")
		elif line.begins_with("|"):
			table_row += 1
			var cells: PackedStringArray = _cells(line)
			# Row 1 is the header and row 2 is the rule under it.
			if table_row > 2 and cells.size() >= 2:
				out.push_back(_inline("%s: %s" % [cells[0], cells[1]]))
		elif current.is_empty():
			current = line
		else:
			current += " " + line
	if not current.is_empty():
		out.push_back(_inline(current))
	return out

static func _cells(row: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	# A private-use character stands in for an escaped bar while the row splits.
	var bar: String = char(0xE000)
	for cell: String in row.replace("\\|", bar).trim_prefix("|").trim_suffix("|").split("|"):
		out.push_back(cell.strip_edges().replace(bar, "|"))
	return out

static func _inline(text: String) -> String:
	var links: RegEx = RegEx.create_from_string("\\[([^\\]]*)\\]\\([^)]*\\)")
	var out: String = links.sub(text, "$1", true)
	return out.replace("**", "").replace("`", "")
