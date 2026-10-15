class_name PlayGamesBackend
extends Node
## What the PlayGames service needs from Google Play Games. Implementations:
## GpgsBackend (the GodotPlayGameServices plugin on Android) and
## FakePlayGamesBackend (debug builds without it). This base class is the
## inert backend: a release build without the plugin gets it, never signs in
## and does nothing, so the game plays exactly as it did before Play Games.
## Ids here are Play Console ids.

## A sign-in check or a sign-in ended.
signal signed_in_changed(signed_in: bool)
## load_cloud() answered: ok false when the service failed; found false when
## the player has no cloud save yet (then `content` is empty).
signal cloud_loaded(ok: bool, found: bool, content: PackedByteArray)
## save_cloud() answered.
signal cloud_saved(ok: bool)
## unlock() answered (false: try again on the next sync).
signal achievement_done(id: String, ok: bool)

## Play Games exists in this build (false: Settings says "Not available").
var available := false


## Starts the SDK and checks sign-in silently (emits signed_in_changed).
func setup() -> void:
	pass


## The interactive sign-in (Settings).
func sign_in() -> void:
	pass


func load_cloud(_name: String) -> void:
	pass


## `progress` is what Google keeps on a conflict (the higher wins).
func save_cloud(_name: String, _description: String, _content: PackedByteArray, _played_ms: int, _progress: int) -> void:
	pass


func unlock(_id: String) -> void:
	pass


func submit_score(_id: String, _score: int) -> void:
	pass


func show_achievements() -> void:
	pass


## Every leaderboard of the game, on Google's own screen.
func show_leaderboards() -> void:
	pass
