extends UnitTest
## [NlaStage]: every stage has a label and a line on what the adults model, read back from any value a file
## or a form hands over.

func test_every_stage_has_a_label_and_a_model_line() -> void:
	for stage: NlaStage.Stage in NlaStage.Stage.values():
		assert_false(NlaStage.label(stage).is_empty(), "stage %d has a label" % stage)
		if stage == NlaStage.Stage.UNKNOWN:
			assert_eq(NlaStage.models(stage), "", "not staged models nothing")
		else:
			assert_true(NlaStage.models(stage).begins_with("Adults model "), "stage %d says what adults model" % stage)
			assert_true(NlaStage.label(stage).begins_with("Stage %d" % stage), "stage %d is numbered in its label" % stage)

func test_from_value_reads_ints_and_strings_and_rejects_the_rest() -> void:
	assert_eq(NlaStage.from_value(3), NlaStage.Stage.SINGLE_WORDS, "an int")
	assert_eq(NlaStage.from_value("4"), NlaStage.Stage.EARLY_GRAMMAR, "a numeric string")
	assert_eq(NlaStage.from_value(0), NlaStage.Stage.UNKNOWN, "zero is not staged")
	assert_eq(NlaStage.from_value(7), NlaStage.Stage.UNKNOWN, "past the last stage")
	assert_eq(NlaStage.from_value(null), NlaStage.Stage.UNKNOWN, "nothing")
	assert_eq(NlaStage.from_value("two"), NlaStage.Stage.UNKNOWN, "a word")
