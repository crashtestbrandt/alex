extends RefCounted
class_name ProfileRepo
## Profiles on disk. One directory per profile under `root`, holding `profile.json` and a `media/` directory
## for recordings. The ProfileStore autoload owns the real one at user://profiles; a test builds one on a
## temporary root.

const PROFILE_FILE: String = "profile.json"
const MEDIA_DIR: String = "media"

var root: String = "user://profiles"

func _init(root_dir: String = "user://profiles") -> void:
	root = root_dir

func profile_dir(profile_id: String) -> String:
	return "%s/%s" % [root, profile_id]

func media_dir(profile_id: String) -> String:
	return "%s/%s" % [profile_dir(profile_id), MEDIA_DIR]

func profile_path(profile_id: String) -> String:
	return "%s/%s" % [profile_dir(profile_id), PROFILE_FILE]

## The ids of every profile directory that holds a profile file, sorted.
func list_ids() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var dir: DirAccess = DirAccess.open(root)
	if dir == null:
		return out
	for sub: String in dir.get_directories():
		if FileAccess.file_exists(profile_path(sub)):
			out.push_back(sub)
	out.sort()
	return out

## The profile with `profile_id`, or null for a missing or unreadable one.
func load_profile(profile_id: String) -> Profile:
	var path: String = profile_path(profile_id)
	if not FileAccess.file_exists(path):
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		printerr("ProfileRepo: %s is not a JSON object" % path)
		return null
	var p: Profile = Profile.from_dict(JsonValue.to_dict(parsed))
	if p == null:
		printerr("ProfileRepo: %s could not be read as a profile" % path)
	return p

## Write `p` to its directory, creating the directory and its media directory. Returns the error, OK on
## success.
func save_profile(p: Profile) -> Error:
	var err: Error = DirAccess.make_dir_recursive_absolute(media_dir(p.id))
	if err != OK:
		return err
	var file: FileAccess = FileAccess.open(profile_path(p.id), FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(p.to_dict(), "  "))
	file.close()
	return OK

## Create, seed and save a profile. `starter` may be null for a blank start.
func create_profile(display_name: String, starter: Starter, style_id: String) -> Profile:
	var p: Profile = Profile.make(new_id(), display_name)
	p.style_id = style_id
	if starter != null:
		starter.seed(p)
	var err: Error = save_profile(p)
	if err != OK:
		printerr("ProfileRepo: could not save new profile %s (%s)" % [p.id, error_string(err)])
		return null
	return p

## Remove a profile and everything in its directory.
func delete_profile(profile_id: String) -> Error:
	var dir_path: String = profile_dir(profile_id)
	if not DirAccess.dir_exists_absolute(dir_path):
		return ERR_DOES_NOT_EXIST
	return _remove_tree(dir_path)

## A new profile id: the creation time plus a random suffix, safe as a directory name.
static func new_id() -> String:
	var stamp: String = Time.get_datetime_string_from_system(true).replace(":", "").replace("-", "")
	return "%s-%04x" % [stamp, randi() % 0x10000]

static func _remove_tree(dir_path: String) -> Error:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return DirAccess.get_open_error()
	for sub: String in dir.get_directories():
		var err: Error = _remove_tree("%s/%s" % [dir_path, sub])
		if err != OK:
			return err
	for file: String in dir.get_files():
		var err: Error = dir.remove(file)
		if err != OK:
			return err
	return DirAccess.remove_absolute(dir_path)
