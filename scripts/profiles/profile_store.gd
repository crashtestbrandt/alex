extends Node
## Autoload `ProfileStore`: the one [ProfileRepo] on the device's user:// directory. Scenes reach profiles
## through this; a test builds its own repo on a temporary root instead.

var repo: ProfileRepo = ProfileRepo.new("user://profiles")

func list_ids() -> PackedStringArray:
	return repo.list_ids()

func load_profile(profile_id: String) -> Profile:
	return repo.load_profile(profile_id)

func save_profile(p: Profile) -> Error:
	return repo.save_profile(p)

func create_profile(display_name: String, starter: Starter, style_id: String) -> Profile:
	return repo.create_profile(display_name, starter, style_id)

func media_dir(profile_id: String) -> String:
	return repo.media_dir(profile_id)

func delete_profile(profile_id: String) -> Error:
	return repo.delete_profile(profile_id)

func last_id() -> String:
	return repo.last_id()

func remember(profile_id: String) -> Error:
	return repo.remember(profile_id)
