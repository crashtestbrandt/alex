extends UnitTest
## [Speaker]'s pure part: the text handed to the OS voice.

func test_a_lone_capital_letter_is_lowercased_for_the_os_voice() -> void:
	assert_eq(Speaker.os_text("I"), "i", "a lone capital would be read as 'capital I'")
	assert_eq(Speaker.os_text(" A "), "a", "trimmed first")
	assert_eq(Speaker.os_text("I want juice"), "I want juice", "a phrase is untouched")
	assert_eq(Speaker.os_text("It's"), "It's", "a word is untouched")
	assert_eq(Speaker.os_text(""), "", "nothing stays nothing")
