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
