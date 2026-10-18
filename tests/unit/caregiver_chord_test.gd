extends UnitTest
## [CaregiverChord]: three fingers, both mouse buttons or Escape fire once after the hold, and nothing else
## does. A hand that moves starts the count again. [ChordProgress.place] keeps the bar beside the hand.

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

func test_one_rolling_finger_keeps_the_count() -> void:
	var c: CaregiverChord = CaregiverChord.new()
	_three_fingers(c)
	assert_false(c.advance(_JUST_SHORT - 0.5), "partway")
	c.drag(1, Vector2(100.0, 100.0 + CaregiverChord.STILL_PX * 2.5))
	assert_true(c.forming(), "the hand's center moved under STILL_PX")
	assert_true(c.advance(0.6), "and the count ran on")

func test_a_moving_hand_restarts_the_count() -> void:
	var c: CaregiverChord = CaregiverChord.new()
	_three_fingers(c)
	assert_false(c.advance(_JUST_SHORT), "almost there")
	var shift: Vector2 = Vector2(0.0, CaregiverChord.STILL_PX * 1.5)
	for i: int in 3:
		c.drag(i, Vector2(100.0 * i, 100.0) + shift)
	assert_true(c.forming(), "the chord stays down")
	assert_false(c.shows_progress(), "its progress hides")
	assert_false(c.advance(0.02), "the count restarted")
	assert_true(c.advance(CaregiverChord.HOLD_SECONDS), "and runs again from where the hand stopped")
	c.drag(7, Vector2.ZERO)
	c.touch(7, false, Vector2.ZERO)
	assert_false(c.forming(), "an unknown finger changes nothing")

func test_progress_shows_after_a_moment_and_fills() -> void:
	var c: CaregiverChord = CaregiverChord.new()
	assert_eq(c.source(), CaregiverChord.Source.NONE, "nothing down")
	_three_fingers(c)
	assert_eq(c.source(), CaregiverChord.Source.FINGERS, "three fingers")
	c.advance(CaregiverChord.SHOW_AFTER - 0.01)
	assert_false(c.shows_progress(), "a brief touch shows nothing")
	c.advance(0.01)
	assert_true(c.shows_progress(), "a held chord shows its progress")
	assert_almost_eq(c.progress(), 0.0, 0.01, "starting empty")
	c.advance((CaregiverChord.HOLD_SECONDS - CaregiverChord.SHOW_AFTER) * 0.5)
	assert_almost_eq(c.progress(), 0.5, 0.01, "halfway at half the shown time")
	assert_eq(c.hand(), Rect2(0.0, 100.0, 200.0, 0.0), "the hand spans the fingers")
	c.touch(2, false, Vector2.ZERO)
	assert_false(c.shows_progress(), "a lifted finger hides it")
	assert_eq(c.progress(), 0.0, "and empties it")

func test_the_bar_sits_beside_the_hand() -> void:
	var screen: Rect2 = Rect2(0.0, 0.0, 1280.0, 800.0)
	var hand: Rect2 = Rect2(500.0, 400.0, 200.0, 50.0)
	var at: Vector2 = ChordProgress.place(hand, screen)
	assert_almost_eq(at.x + ChordProgress.BAR_SIZE.x * 0.5, hand.get_center().x, 0.01, "centered on the hand")
	assert_almost_eq(at.y + ChordProgress.BAR_SIZE.y, hand.position.y - ChordProgress.GAP_PX, 0.01, "above it")
	var high: Rect2 = Rect2(500.0, 40.0, 200.0, 50.0)
	assert_almost_eq(ChordProgress.place(high, screen).y, high.end.y + ChordProgress.GAP_PX, 0.01, "below a hand at the top")
	var corner: Vector2 = ChordProgress.place(Rect2(1270.0, 790.0, 0.0, 0.0), screen)
	assert_true(Rect2(corner, ChordProgress.BAR_SIZE).end.x <= screen.end.x - ChordProgress.MARGIN_PX, "inside the right edge")
	assert_true(Rect2(corner, ChordProgress.BAR_SIZE).end.y <= screen.end.y, "inside the bottom edge")

func test_both_mouse_buttons_fire() -> void:
	var c: CaregiverChord = CaregiverChord.new()
	c.mouse_button(MOUSE_BUTTON_LEFT, true)
	assert_false(c.advance(CaregiverChord.HOLD_SECONDS * 2.0), "the left button alone")
	c.mouse_button(MOUSE_BUTTON_RIGHT, true)
	assert_eq(c.source(), CaregiverChord.Source.MOUSE, "both buttons form the chord")
	assert_true(c.advance(CaregiverChord.HOLD_SECONDS), "and fire after the hold")
	c.mouse_button(MOUSE_BUTTON_RIGHT, true)
	c.mouse_button(MOUSE_BUTTON_LEFT, false)
	assert_false(c.forming(), "the right button alone")

func test_escape_fires() -> void:
	var c: CaregiverChord = CaregiverChord.new()
	c.escape(true)
	assert_eq(c.source(), CaregiverChord.Source.ESCAPE, "Escape forms the chord")
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
