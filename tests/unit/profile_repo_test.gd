extends UnitTest
## [ProfileRepo] on a temporary root under user://: create, list, load, save and delete. Every method gets a
## fresh root and teardown removes it, so a failed run leaves nothing behind.

var _repo: ProfileRepo = null

func setup() -> void:
	_repo = ProfileRepo.new("user://test-profiles-%08x" % (randi() % 0x7fffffff))

func teardown() -> void:
	for profile_id: String in _repo.list_ids():
		_repo.delete_profile(profile_id)
	DirAccess.remove_absolute(_repo.root)
	_repo = null

func test_empty_root_lists_nothing() -> void:
	assert_eq(_repo.list_ids().size(), 0, "no profiles")
	assert_null(_repo.load_profile("nope"), "a missing profile is null")

func test_create_seeds_from_a_starter_and_is_listed() -> void:
	var starter: Starter = Starter.from_dict({
		"id": "s", "title": "S",
		"gestalts": [{"id": "a", "text": "Let's go | outside"}],
		"boards": [{"id": "home", "title": "Home", "gestalts": ["a"]}],
	})
	var p: Profile = _repo.create_profile("Sam", starter, "calm")
	assert_not_null(p, "created")
	assert_eq(_repo.list_ids(), PackedStringArray([p.id]), "listed by id")
	assert_eq(p.starter_id, "s", "remembers its starter")
	assert_eq(p.gestalts.size(), 1, "seeded gestalts")
	assert_eq(p.boards.size(), 1, "seeded boards")
	assert_true(DirAccess.dir_exists_absolute(_repo.media_dir(p.id)), "media dir created")

func test_create_without_a_starter_is_blank() -> void:
	var p: Profile = _repo.create_profile("Sam", null, "bold")
	assert_not_null(p, "created")
	assert_eq(p.gestalts.size(), 0, "no gestalts")
	assert_eq(p.style_id, "bold", "style kept")

func test_save_then_load_round_trips() -> void:
	var p: Profile = _repo.create_profile("Sam", null, "calm")
	p.stage = NlaStage.Stage.SINGLE_WORDS
	p.put_gestalt(Gestalt.from_text("x", "All | done"))
	assert_eq(_repo.save_profile(p), OK, "saved")
	var back: Profile = _repo.load_profile(p.id)
	assert_not_null(back, "loaded")
	assert_eq(back.stage, NlaStage.Stage.SINGLE_WORDS, "stage persisted")
	assert_eq(back.gestalts.size(), 1, "gestalt persisted")

func test_seeding_twice_does_not_duplicate() -> void:
	var starter: Starter = Starter.from_dict({
		"id": "s", "gestalts": [{"id": "a", "text": "hi"}], "boards": [{"id": "b", "gestalts": ["a"]}],
	})
	var p: Profile = _repo.create_profile("Sam", starter, "calm")
	starter.seed(p)
	assert_eq(p.gestalts.size(), 1, "gestalts replaced by id")
	assert_eq(p.boards.size(), 1, "boards replaced by id")

func test_delete_removes_the_directory() -> void:
	var p: Profile = _repo.create_profile("Sam", null, "calm")
	assert_eq(_repo.delete_profile(p.id), OK, "deleted")
	assert_eq(_repo.list_ids().size(), 0, "gone from the list")
	assert_eq(_repo.delete_profile(p.id), ERR_DOES_NOT_EXIST, "deleting again says so")

func test_ids_are_unique_and_directory_safe() -> void:
	var a: String = ProfileRepo.new_id()
	var b: String = ProfileRepo.new_id()
	assert_true(a != b, "two ids differ")
	assert_true(a.is_valid_filename(), "an id is a valid directory name")
