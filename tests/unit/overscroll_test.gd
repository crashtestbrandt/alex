extends UnitTest
## [Overscroll]: the band follows a short pull, resists a long one and never reaches the view's height; a pull
## builds only at an end and gives back first; a fling carries a little past an end, never more than a share
## of the view.

func test_band_follows_a_short_pull_at_the_resistance() -> void:
	assert_almost_eq(Overscroll.band(1.0, 800.0), Overscroll.RESISTANCE, 0.01, "the first pixel moves about half")
	assert_eq(Overscroll.band(0.0, 800.0), 0.0, "no pull shows nothing")
	assert_eq(Overscroll.band(50.0, 0.0), 0.0, "a view with no height shows nothing")

func test_band_resists_more_the_further_it_goes() -> void:
	var near: float = Overscroll.band(100.0, 800.0)
	var far: float = Overscroll.band(1000.0, 800.0)
	assert_true(near > 0.0 and near < 100.0 * Overscroll.RESISTANCE, "a pull shows less than it travels")
	assert_true(far > near, "a longer pull shows more")
	assert_true(far / 1000.0 < near / 100.0, "and gives less per pixel")
	assert_true(Overscroll.band(1000000.0, 800.0) < 800.0, "never the whole view")

func test_band_keeps_the_sign() -> void:
	assert_almost_eq(Overscroll.band(-100.0, 800.0), -Overscroll.band(100.0, 800.0), 0.0001, "past the bottom mirrors the top")

func test_unband_inverts_band() -> void:
	for pull: float in [5.0, 80.0, 400.0, -60.0, -900.0]:
		assert_almost_eq(Overscroll.unband(Overscroll.band(pull, 600.0), 600.0), pull, 0.01, "round trip %s" % pull)
	assert_eq(Overscroll.unband(0.0, 600.0), 0.0, "nothing shown is no pull")

func test_drag_builds_only_at_an_end() -> void:
	assert_eq(Overscroll.drag(0.0, 10.0, true, false), 10.0, "pulling down at the top builds")
	assert_eq(Overscroll.drag(0.0, -10.0, false, true), -10.0, "pulling up at the bottom builds")
	assert_eq(Overscroll.drag(0.0, 10.0, false, false), 0.0, "in the middle the content scrolls instead")
	assert_eq(Overscroll.drag(0.0, -10.0, true, false), 0.0, "pulling up at the top scrolls")
	assert_eq(Overscroll.drag(0.0, 10.0, false, true), 0.0, "pulling down at the bottom scrolls")

func test_drag_gives_back_before_it_scrolls() -> void:
	assert_eq(Overscroll.drag(30.0, 10.0, true, false), 40.0, "further down pulls further")
	assert_eq(Overscroll.drag(30.0, -10.0, true, false), 20.0, "back up gives some back")
	assert_eq(Overscroll.drag(30.0, -50.0, true, false), 0.0, "and stops at none")
	assert_eq(Overscroll.drag(-30.0, 50.0, false, true), 0.0, "the bottom gives back the same way")

func test_fling_carries_a_little_past_the_end() -> void:
	var carry: float = Overscroll.fling(2000.0, 800.0)
	assert_true(carry > 0.0 and carry < 2000.0 * Overscroll.FLING_SECONDS, "a fast fling carries a banded distance")
	assert_true(Overscroll.fling(-2000.0, 800.0) < 0.0, "a fling up carries up")
	assert_eq(Overscroll.fling(0.0, 800.0), 0.0, "no speed carries nothing")

func test_fling_is_capped_at_a_share_of_the_view() -> void:
	var limit: float = 800.0 * Overscroll.FLING_MAX_SHARE
	assert_almost_eq(Overscroll.fling(1000000.0, 800.0), limit, 0.001, "a very fast fling stops at the cap")
	assert_almost_eq(Overscroll.fling(-1000000.0, 800.0), -limit, 0.001, "in either direction")
