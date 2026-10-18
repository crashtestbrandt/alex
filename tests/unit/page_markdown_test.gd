extends UnitTest

func test_heading_emphasis_and_code_render() -> void:
	var rendered: String = PageMarkdown.render("# Title\n\n## A **heading**\n\nSome *emphasis*, **bold**, and `a[b]`.")
	assert_false(rendered.contains("Title"), "the sheet owns the title")
	assert_true(rendered.contains("[font_size=28][b]A [b]heading[/b][/b][/font_size]"), "heading keeps its hierarchy")
	assert_true(rendered.contains("[i]emphasis[/i], [b]bold[/b], and [code]a[lb]b][/code]"), "inline styling survives")

func test_lists_keep_wrapped_items() -> void:
	assert_eq(PageMarkdown.render("- One\n  continuation\n- Two\n\n1. First\n2. Second"), "[ul]One continuation\nTwo[/ul]\n\n[ol]First\nSecond[/ol]", "lists retain hanging indents and numbering")

func test_tables_keep_headers_columns_and_escaped_pipes() -> void:
	var rendered: String = PageMarkdown.render("| Term | Meaning |\n| --- | --- |\n| **Chunk** | a \\| b and `x|y` |")
	assert_true(rendered.contains("[table=2]"), "a real two-column table")
	assert_true(rendered.contains("[b]Term[/b]"), "the table header remains")
	assert_true(rendered.contains("[b]Chunk[/b]"), "cell formatting remains")
	assert_true(rendered.contains("a | b and [code]x|y[/code]"), "bars stay inside cells")
	assert_eq(rendered.count("[cell "), 4, "escaped bars do not create columns")

func test_markdown_cannot_inject_bbcode_or_executable_links() -> void:
	assert_eq(PageMarkdown.inline_text("[img]private.png[/img]"), "[lb]img]private.png[lb]/img]", "BBCode stays literal")
	assert_eq(PageMarkdown.inline_text("[no](file:///secret)"), "no", "local resources are never opened")
	assert_eq(PageMarkdown.inline_text("[guide](https://example.com/guide)"), "[url=https://example.com/guide]guide[/url]", "web links keep their target")
	assert_false(PageMarkdown.safe_link("https://example.com/[b]"), "link metadata cannot inject tags")

func test_code_fences_do_not_parse_markdown() -> void:
	assert_eq(PageMarkdown.render("```\n**literal** [url]x\n```"), "[code]**literal** [lb]url]x\n[/code]", "fenced text stays literal")

func test_all_shipped_pages_render_structure() -> void:
	for path: String in [PageText.GUIDE, PageText.GLOSSARY, PageText.PRIVACY]:
		var rendered: String = PageMarkdown.render(FileAccess.get_file_as_string(path))
		assert_false(rendered.is_empty(), "%s renders" % path)
		assert_true(rendered.contains("[table=") or rendered.contains("[ul]"), "%s preserves structure" % path)
