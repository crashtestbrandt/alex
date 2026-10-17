extends UnitTest
## [BuildStamp]: a release, a candidate and a local export read as label and build number; an editor run reads
## "dev"; an empty label falls back to "dev".

func test_a_release_shows_label_and_build() -> void:
	assert_eq(BuildStamp.text("0.1.2", 34), "0.1.2 (34)", "release")
	assert_eq(BuildStamp.text("0.1.2-rc.1", 34), "0.1.2-rc.1 (34)", "candidate")
	assert_eq(BuildStamp.text("dev", 34), "dev (34)", "local export")

func test_no_build_shows_the_label_alone() -> void:
	assert_eq(BuildStamp.text("dev", 0), "dev", "an editor run")
	assert_eq(BuildStamp.text("0.1.2", -1), "0.1.2", "a negative number is no build")

func test_an_empty_label_is_dev() -> void:
	assert_eq(BuildStamp.text("", 0), "dev", "nothing stamped")
	assert_eq(BuildStamp.text("  ", 12), "dev (12)", "blank")

func test_this_run_reads_the_project_settings() -> void:
	assert_eq(BuildStamp.current(), "dev", "project.godot holds dev and 0 outside an export")
