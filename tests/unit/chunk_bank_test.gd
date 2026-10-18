extends UnitTest
## [ChunkBank]: beginnings and endings come out once each by key and in bank order, a strip that says a bank
## phrase is that phrase, and any other strip is voiced as itself.

func _bank() -> Array[Gestalt]:
	var out: Array[Gestalt] = []
	out.push_back(Gestalt.from_text("a", "Let's go | outside"))
	out.push_back(Gestalt.from_text("b", "Let's go | in the car"))
	out.push_back(Gestalt.from_text("c", "All done"))
	out.push_back(Gestalt.from_text("d", "It's time for | a snack"))
	out.push_back(Gestalt.from_text("e", "LET'S GO | outside | now"))
	return out

func test_beginnings_are_first_chunks_once_each() -> void:
	assert_eq(ChunkBank.beginnings(_bank()), PackedStringArray(["Let's go", "All done", "It's time for"]), "first chunks, bank order, a repeat merged whatever its casing")

func test_endings_are_later_chunks_once_each() -> void:
	assert_eq(ChunkBank.endings(_bank()), PackedStringArray(["outside", "in the car", "a snack", "now"]), "later chunks, bank order, a repeat merged")
	assert_true(ChunkBank.endings([] as Array[Gestalt]).is_empty(), "an empty bank has no endings")

func test_next_is_what_follows_a_chunk_once_each() -> void:
	assert_eq(ChunkBank.next(_bank(), "let's GO"), PackedStringArray(["outside", "in the car"]), "what follows, bank order, by key, a repeat merged")
	assert_eq(ChunkBank.next(_bank(), "outside"), PackedStringArray(["now"]), "a middle chunk has a follower")
	assert_true(ChunkBank.next(_bank(), "now").is_empty(), "a last chunk has none")
	assert_true(ChunkBank.next(_bank(), "All done").is_empty(), "nor does a whole gestalt")
	assert_true(ChunkBank.next(_bank(), "  ").is_empty(), "nor a blank")

func test_leads_are_beginnings_then_followers() -> void:
	assert_eq(ChunkBank.leads(_bank(), PackedStringArray()), ChunkBank.beginnings(_bank()), "an empty strip leads with every beginning")
	assert_eq(ChunkBank.leads(_bank(), PackedStringArray(["Let's go"])), PackedStringArray(["outside", "in the car"]), "after a chunk, what follows it")
	assert_eq(ChunkBank.leads(_bank(), PackedStringArray(["Let's go", "outside"])), PackedStringArray(["now"]), "only the last chunk decides")
	assert_true(ChunkBank.leads(_bank(), PackedStringArray(["a snack"])).is_empty(), "a finished phrase leads nowhere")

func test_a_whole_gestalt_is_a_beginning_with_no_ending() -> void:
	var bank: Array[Gestalt] = [Gestalt.from_text("c", "All done")]
	assert_eq(ChunkBank.beginnings(bank), PackedStringArray(["All done"]), "it begins")
	assert_true(ChunkBank.endings(bank).is_empty(), "and nothing follows")

func test_match_finds_the_bank_phrase_by_key() -> void:
	var bank: Array[Gestalt] = _bank()
	var hit: Gestalt = ChunkBank.find(bank, PackedStringArray(["Let's go", "outside"]))
	assert_not_null(hit, "found")
	assert_eq(hit.id, "a", "the first match in bank order")
	assert_eq(ChunkBank.find(bank, PackedStringArray(["let's go", "OUTSIDE"])).id, "a", "casing does not matter")
	assert_null(ChunkBank.find(bank, PackedStringArray(["outside", "Let's go"])), "order matters")
	assert_null(ChunkBank.find(bank, PackedStringArray(["Let's go"])), "a beginning alone is not the phrase")
	assert_null(ChunkBank.find(bank, PackedStringArray()), "an empty strip matches nothing")

func test_voice_is_the_bank_gestalt_or_a_transient_one() -> void:
	var bank: Array[Gestalt] = _bank()
	bank[0].recording = "a.wav"
	assert_eq(ChunkBank.voice(bank, PackedStringArray(["Let's go", "outside"])).recording, "a.wav", "a built bank phrase keeps its recording")
	var other: Gestalt = ChunkBank.voice(bank, PackedStringArray(["Let's go", "a snack"]))
	assert_eq(other.id, ChunkBank.BUILD_ID, "another strip is transient")
	assert_eq(other.text, "Let's go a snack", "and says the strip")
	assert_eq(other.chunks, PackedStringArray(["Let's go", "a snack"]), "with the strip's seams")
	assert_true(other.recording.is_empty(), "with no recording yet")
