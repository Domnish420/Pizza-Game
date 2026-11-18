extends Node
## Art layer. Every picture in the game is requested here by key.
## If res://assets/<key with dots as dashes>.png exists it is used; otherwise the caller draws a placeholder shape.
## So the game is fully playable with no artwork, and art is added by dropping PNG files into assets/.
## Example: key "bg.van" -> res://assets/bg-van.png. See ART_KEYS.md for the full list.

var _cache := {}

func tex(key: String) -> Texture2D:
	if _cache.has(key):
		return _cache[key]
	var path := "res://assets/" + key.replace(".", "-") + ".png"
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path)
	_cache[key] = t
	return t

## Optional sound effects: res://assets/sfx/<name>.wav (ding, cash, bad, tap, up).
var _players := {}
func sfx(sound: String) -> void:
	if Game.s.get("mute", false):
		return
	if not _players.has(sound):
		var path := "res://assets/sfx/" + sound + ".wav"
		var p: AudioStreamPlayer = null
		if ResourceLoader.exists(path):
			p = AudioStreamPlayer.new()
			p.stream = load(path)
			add_child(p)
		_players[sound] = p
	if _players[sound] != null:
		_players[sound].play()

## A 3D model by key: res://assets/models/<key with dots as dashes>.glb (or .gltf / .tscn), instanced.
## null if there is none yet, and the 3D kitchen builds a placeholder shape instead. See ART_KEYS.md.
var _models := {}
func model(key: String) -> Node3D:
	if not _models.has(key):
		_models[key] = null
		for ext in [".glb", ".gltf", ".tscn"]:
			var path: String = "res://assets/models/" + key.replace(".", "-") + ext
			if ResourceLoader.exists(path):
				_models[key] = load(path)
				break
	var ps = _models[key]
	if ps is PackedScene: return ps.instantiate() as Node3D
	return null

## is there a model for this key (so the game can fit it: stretch a pan, find a named part)
func has_model(key: String) -> bool:
	if not _models.has(key): model(key)
	return _models[key] is PackedScene
