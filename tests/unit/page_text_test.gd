extends UnitTest
## [PageText]: the Markdown subset PRIVACY.md uses comes out as plain blocks, and the real PRIVACY.md reads
## with no Markdown left in it.

func test_title_is_dropped_and_headings_are_blocks() -> void:
	assert_eq(PageText.blocks("# Privacy policy\n\n## Children\n\nText."), PackedStringArray(["Children", "Text."]), "the title goes, the heading stays")

func test_headings_list_the_section_blocks() -> void:
	assert_eq(PageText.headings("# Title\n\n## The **microphone**\n\nText.\n\n## Children"), PackedStringArray(["The microphone", "Children"]), "level-two headings only, marks removed")

func test_paragraph_lines_join() -> void:
	assert_eq(PageText.blocks("One line\nand the next.\n\nSecond."), PackedStringArray(["One line and the next.", "Second."]), "two paragraphs")

func test_items_get_a_bullet_and_keep_their_continuation() -> void:
	var md: String = "- First item\n  goes on.\n- Second item."
	assert_eq(PageText.blocks(md), PackedStringArray(["• First item goes on.", "• Second item."]), "one block per item")

func test_table_rows_become_label_value_lines() -> void:
	var md: String = "| Data | Why |\n| --- | --- |\n| Names | To show them. |\n| Voices | To play them. |"
	assert_eq(PageText.blocks(md), PackedStringArray(["Names: To show them.", "Voices: To play them."]), "header and rule dropped")

func test_inline_marks_keep_their_text() -> void:
	assert_eq(PageText.blocks("Choose **Edit**, see `a.md` and [the issues](https://example.com)."), PackedStringArray(["Choose Edit, see a.md and the issues."]), "bold, code and links")

func test_a_table_after_a_paragraph_starts_fresh() -> void:
	var md: String = "Intro:\n\n| A | B |\n| --- | --- |\n| x | y |\n\nAfter."
	assert_eq(PageText.blocks(md), PackedStringArray(["Intro:", "x: y", "After."]), "the table sits between paragraphs")

func test_the_shipped_policy_reads_as_plain_text() -> void:
	var blocks: PackedStringArray = PageText.load_blocks(PageText.PRIVACY)
	assert_true(blocks.size() > 10, "PRIVACY.md is at res:// and has its sections")
	assert_eq(blocks[0], "Alex Language Explorer (\"Alex\") collects no personal data. Nothing you put into Alex leaves your device.", "the opening statement comes first")
	for block: String in blocks:
		assert_false(block.contains("**") or block.contains("`") or block.contains("|") or block.begins_with("#") or block.begins_with("- "), "no Markdown left in: %s" % block)

func test_the_shipped_guide_reads_as_plain_text() -> void:
	var blocks: PackedStringArray = PageText.load_blocks(PageText.GUIDE)
	assert_true(blocks.size() > 10, "GUIDE.md is at res:// and has its sections")
	assert_true(PageText.load_headings(PageText.GUIDE).has("Open caregiver mode"), "it starts with how to get here")
	for block: String in blocks:
		assert_false(block.contains("**") or block.contains("`") or block.contains("|") or block.begins_with("#") or block.begins_with("- "), "no Markdown left in: %s" % block)
