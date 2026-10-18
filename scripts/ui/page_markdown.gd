extends RefCounted
class_name PageMarkdown
## The shipped pages' Markdown rendered as RichTextLabel BBCode. PageText remains the plain-text export
## reader. No HTML or images are evaluated, and literal BBCode in a page stays literal.

static var _heading_pattern: RegEx = RegEx.create_from_string("^(#{1,6}) +(.+)$")
static var _item_pattern: RegEx = RegEx.create_from_string("^(?:([-+*])|([0-9]+)[.)]) +(.+)$")
static var _table_pattern: RegEx = RegEx.create_from_string("^:?-{3,}:?$")
static var _unsafe_link_pattern: RegEx = RegEx.create_from_string("[\\s\\[\\]<>\"']")

static func render(markdown: String, heading_size: int = 28) -> String:
	var lines: PackedStringArray = markdown.replace("\r\n", "\n").split("\n")
	var out: PackedStringArray = []
	var paragraph: PackedStringArray = []
	var list_tag: String = ""
	var code: bool = false
	var i: int = 0
	while i < lines.size():
		var line: String = lines[i].strip_edges()
		if line.begins_with("```"):
			_flush(paragraph, out)
			if not list_tag.is_empty():
				out.push_back("[/" + list_tag + "]\n")
				list_tag = ""
			out.push_back("[/code]\n\n" if code else "[code]")
			code = not code
			i += 1
			continue
		if code:
			out.push_back(escape(lines[i]) + "\n")
			i += 1
			continue
		var heading: RegExMatch = _heading_pattern.search(line)
		var item: RegExMatch = _item_pattern.search(line)
		var table: bool = line.begins_with("|") and i + 1 < lines.size() and _table_rule(lines[i + 1])
		if line.is_empty() or heading != null or item != null or table:
			_flush(paragraph, out)
		if not list_tag.is_empty() and (line.is_empty() or heading != null or table or (item != null and ("ul" if not item.get_string(1).is_empty() else "ol") != list_tag)):
			out.push_back("[/" + list_tag + "]\n\n")
			list_tag = ""
		if heading != null:
			# The page already has its title in the caregiver sheet.
			var level: int = heading.get_string(1).length()
			if level > 1:
				out.push_back("[font_size=%d][b]%s[/b][/font_size]\n\n" % [maxi(heading_size - (level - 2) * 2, 20), inline_text(heading.get_string(2))])
		elif table:
			var header: PackedStringArray = cells(line)
			out.push_back("[table=%d]" % header.size())
			_table_cells(header, header.size(), true, out)
			i += 2
			while i < lines.size() and lines[i].strip_edges().begins_with("|"):
				_table_cells(cells(lines[i]), header.size(), false, out)
				i += 1
			out.push_back("[/table]\n\n")
			continue
		elif item != null:
			if list_tag.is_empty():
				list_tag = "ul" if not item.get_string(1).is_empty() else "ol"
				out.push_back("[" + list_tag + "]")
			else:
				out.push_back("\n")
			out.push_back(inline_text(item.get_string(3)))
		elif not line.is_empty():
			if not list_tag.is_empty():
				out.push_back(" " + inline_text(line))
			else:
				paragraph.push_back(line)
		i += 1
	_flush(paragraph, out)
	if not list_tag.is_empty():
		out.push_back("[/" + list_tag + "]")
	if code:
		out.push_back("[/code]")
	return "".join(out).strip_edges()

static func _flush(paragraph: PackedStringArray, out: PackedStringArray) -> void:
	if not paragraph.is_empty():
		out.push_back(inline_text(" ".join(paragraph)) + "\n\n")
		paragraph.clear()

static func _table_rule(line: String) -> bool:
	var row: PackedStringArray = cells(line.strip_edges())
	if row.is_empty():
		return false
	for cell: String in row:
		if _table_pattern.search(cell) == null:
			return false
	return true

## An escaped bar or a bar inside inline code belongs to its cell.
static func cells(line: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var cell: String = ""
	var quoted: bool = false
	var escaped: bool = false
	for character: String in line.strip_edges().trim_prefix("|").trim_suffix("|"):
		if escaped:
			cell += "\\" + character
			escaped = false
		elif character == "\\":
			escaped = true
		elif character == "`":
			quoted = not quoted
			cell += character
		elif character == "|" and not quoted:
			out.push_back(cell.strip_edges())
			cell = ""
		else:
			cell += character
	if escaped:
		cell += "\\"
	out.push_back(cell.strip_edges())
	return out

static func _table_cells(row: PackedStringArray, columns: int, header: bool, out: PackedStringArray) -> void:
	for i: int in columns:
		var text: String = inline_text(row[i]) if i < row.size() else ""
		var ratio: int = 2 if columns == 2 and i == 1 else 1
		out.push_back("[cell expand=%d padding=4,8,12,8]%s[/cell]" % [ratio, "[b]" + text + "[/b]" if header else text])

static func escape(text: String) -> String:
	return text.replace("[", "[lb]")

static func safe_link(url: String) -> bool:
	return (url.begins_with("https://") or url.begins_with("http://")) and not _unsafe_link_pattern.search(url)

## Parse inline syntax before escaping so Markdown cannot introduce arbitrary BBCode tags.
static func inline_text(text: String) -> String:
	var out: String = ""
	var i: int = 0
	while i < text.length():
		if text[i] == "\\" and i + 1 < text.length():
			out += escape(text[i + 1])
			i += 2
			continue
		if text[i] == "`":
			var end: int = text.find("`", i + 1)
			if end >= 0:
				out += "[code]" + escape(text.substr(i + 1, end - i - 1)) + "[/code]"
				i = end + 1
				continue
		if text[i] == "[":
			var middle: int = text.find("](", i + 1)
			var end: int = text.find(")", middle + 2) if middle >= 0 else -1
			if end >= 0:
				var label: String = inline_text(text.substr(i + 1, middle - i - 1))
				var url: String = text.substr(middle + 2, end - middle - 2)
				out += "[url=%s]%s[/url]" % [url, label] if safe_link(url) else label
				i = end + 1
				continue
		var matched: bool = false
		for mark: String in ["**", "__", "~~", "*", "_"]:
			if not text.substr(i).begins_with(mark):
				continue
			var end: int = text.find(mark, i + mark.length())
			if end <= i + mark.length():
				continue
			var tag: String = "b" if mark.length() == 2 else "i"
			if mark == "~~":
				tag = "s"
			out += "[%s]%s[/%s]" % [tag, inline_text(text.substr(i + mark.length(), end - i - mark.length())), tag]
			i = end + mark.length()
			matched = true
			break
		if not matched:
			out += escape(text[i])
			i += 1
	return out
