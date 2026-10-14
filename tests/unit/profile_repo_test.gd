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

func test_delete_removes_all_takes_and_hidden_files_but_keeps_other_profiles() -> void:
	var target: Profile = _repo.create_profile("Sam", null, "calm")
	var other: Profile = _repo.create_profile("Sam", null, "calm")
	var media: String = _repo.media_dir(target.id)
	DirAccess.make_dir_recursive_absolute(media.path_join("name"))
	DirAccess.make_dir_recursive_absolute(media.path_join(".hidden"))
	for relative: String in ["phrase.wav", "phrase.prev.wav", "name/name.wav", "name/name.prev.wav", ".hidden/take.tmp"]:
		var file: FileAccess = FileAccess.open(media.path_join(relative), FileAccess.WRITE)
		file.store_string("synthetic deletion fixture")
		file.close()
	assert_eq(_repo.delete_profile(target.id), OK, "complete deletion")
	assert_false(DirAccess.dir_exists_absolute(_repo.profile_dir(target.id)), "profile directory and nested media removed")
	assert_not_null(_repo.load_profile(other.id), "same-name sibling remains")
	assert_eq(_repo.list_ids(), PackedStringArray([other.id]), "only the selected id disappears")

func test_delete_rejects_paths_outside_one_profile_directory() -> void:
	var p: Profile = _repo.create_profile("Sam", null, "calm")
	for id: String in ["", ".", "..", "../outside", "/absolute", p.id + "/media", p.id + "\\media"]:
		assert_eq(_repo.delete_profile(id), ERR_INVALID_PARAMETER, "unsafe id rejected: " + id)
	assert_not_null(_repo.load_profile(p.id), "invalid deletion never touches the profile root")

func test_delete_does_not_follow_directory_links() -> void:
	# Windows may require elevated privileges to create a link. Linux and macOS exercise unlinking.
	if OS.get_name() == "Windows":
		return
	var target: Profile = _repo.create_profile("Target", null, "calm")
	var other: Profile = _repo.create_profile("Other", null, "calm")
	var media: DirAccess = DirAccess.open(_repo.media_dir(target.id))
	var other_path: String = ProjectSettings.globalize_path(_repo.profile_dir(other.id))
	assert_eq(media.create_link(other_path, "linked-profile"), OK, "directory link fixture")
	assert_eq(_repo.delete_profile(target.id), OK, "link removed with the target profile")
	assert_not_null(_repo.load_profile(other.id), "linked profile's contents survive")
	var root_dir: DirAccess = DirAccess.open(_repo.root)
	assert_eq(root_dir.create_link(other_path, "alias"), OK, "root link fixture")
	assert_eq(_repo.delete_profile("alias"), ERR_INVALID_PARAMETER, "root links are not traversed")
	assert_eq(root_dir.remove("alias"), OK, "remove test alias")
