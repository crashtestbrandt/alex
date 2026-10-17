extends UnitTest
## [CaregiverChord]: three fingers held still, both mouse buttons or Escape fire once after the hold, and
## nothing else does.

const _JUST_SHORT: float = CaregiverChord.HOLD_SECONDS - 0.01

func _three_fingers(c: CaregiverChord) -> void:
	for i: int in 3:
		c.touch(i, true, Vector2(100.0 * i, 100.0))

func test_three_fingers_fire_after_the_hold() -> void:
	var c: CaregiverChord = CaregiverChord.new()
	_three_fingers(c)
	assert_true(c.forming(), "three fingers form the chord")
	assert_false(c.advance(_JUST_SHORT), "not before the hold")
	assert_true(c.advance(0.02), "at the hold")
	assert_false(c.forming(), "the chord starts over")
	assert_false(c.advance(CaregiverChord.HOLD_SECONDS), "a hand that stays down does not fire again")

func test_other_finger_counts_do_nothing() -> void:
	var c: CaregiverChord = CaregiverChord.new()
	c.touch(0, true, Vector2.ZERO)
	c.touch(1, true, Vector2(100.0, 0.0))
	assert_false(c.advance(CaregiverChord.HOLD_SECONDS * 2.0), "two fingers")
	_three_fingers(c)
	c.touch(3, true, Vector2(400.0, 0.0))
	assert_false(c.advance(CaregiverChord.HOLD_SECONDS * 2.0), "four fingers")

func test_a_change_in_fingers_restarts_the_count() -> void:
	var c: CaregiverChord = CaregiverChord.new()
	_three_fingers(c)
	assert_false(c.advance(_JUST_SHORT), "almost there")
	c.touch(3, true, Vector2(400.0, 0.0))
	c.touch(3, false, Vector2(400.0, 0.0))
	assert_false(c.advance(0.02), "the count restarted when the fourth finger came and went")
	assert_true(c.advance(CaregiverChord.HOLD_SECONDS), "and runs again from there")

func test_a_wandering_finger_breaks_the_chord() -> void:
	var c: CaregiverChord = CaregiverChord.new()
	_three_fingers(c)
	c.drag(1, Vector2(100.0, 100.0 + CaregiverChord.STILL_PX * 0.5))
	assert_true(c.forming(), "a small drift is still")
	c.drag(1, Vector2(100.0, 100.0 + CaregiverChord.STILL_PX * 2.0))
	assert_false(c.forming(), "a finger that wanders breaks it")
	assert_false(c.advance(CaregiverChord.HOLD_SECONDS * 2.0), "and nothing fires")
	c.drag(7, Vector2.ZERO)
	c.touch(7, false, Vector2.ZERO)
	assert_false(c.forming(), "an unknown finger changes nothing")

func test_both_mouse_buttons_fire() -> void:
	var c: CaregiverChord = CaregiverChord.new()
	c.mouse_button(MOUSE_BUTTON_LEFT, true)
	assert_false(c.advance(CaregiverChord.HOLD_SECONDS * 2.0), "the left button alone")
	c.mouse_button(MOUSE_BUTTON_RIGHT, true)
	assert_true(c.forming(), "both buttons form the chord")
	assert_true(c.advance(CaregiverChord.HOLD_SECONDS), "and fire after the hold")
	c.mouse_button(MOUSE_BUTTON_RIGHT, true)
	c.mouse_button(MOUSE_BUTTON_LEFT, false)
	assert_false(c.forming(), "the right button alone")

func test_escape_fires() -> void:
	var c: CaregiverChord = CaregiverChord.new()
	c.escape(true)
	assert_false(c.advance(_JUST_SHORT), "not before the hold")
	assert_true(c.advance(0.02), "at the hold")
	c.escape(true)
	c.escape(false)
	assert_false(c.advance(CaregiverChord.HOLD_SECONDS), "a released key does nothing")

func test_reset_forgets_everything() -> void:
	var c: CaregiverChord = CaregiverChord.new()
	_three_fingers(c)
	c.mouse_button(MOUSE_BUTTON_LEFT, true)
	c.mouse_button(MOUSE_BUTTON_RIGHT, true)
	c.escape(true)
	c.reset()
	assert_false(c.forming(), "nothing is down")
	assert_false(c.advance(CaregiverChord.HOLD_SECONDS), "and nothing fires")
