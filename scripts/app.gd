extends Node
## Autoload `App`: the active profile and the app's display name. Scene-independent state only; every screen
## reads the profile from here rather than carrying its own copy.

## The name every player-facing surface uses. The repository and the Godot project stay `jessie`.
const DISPLAY_NAME: String = "Jessie"

signal profile_changed(profile: Profile)

var active_profile: Profile = null

func set_active_profile(p: Profile) -> void:
	active_profile = p
	profile_changed.emit(p)

func has_profile() -> bool:
	return active_profile != null
