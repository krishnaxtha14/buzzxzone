extends Node

var player_name:        String = "PLAYER"
var score:              int   = 0
var lives:              int   = 3
var current_mission:    int   = 1
var missions_completed: Array = []

# Combo system
var combo_streak:   int   = 0
var combo_mult:     float = 1.0

# Per-mission scores for results breakdown
var mission_scores: Dictionary = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0}

signal combo_changed(streak: int, mult: float)
signal score_changed(new_score: int)
signal lives_changed(new_lives: int)

func _ready():
	lives = SettingsManager.get_lives() if SettingsManager else 3
	_fetch_player_name()

# On web, the host page passes the logged-in username as ?user=... — read it
# via the JS bridge so the game can greet the real player instead of a
# placeholder character.
func _fetch_player_name():
	if not OS.has_feature("web"):
		return
	var n = JavaScriptBridge.eval(
		"new URLSearchParams(window.location.search).get('user') || ''", true)
	if typeof(n) == TYPE_STRING and n.strip_edges() != "":
		player_name = n.strip_edges()

func add_score(base_points: int) -> int:
	combo_streak += 1
	_update_mult()
	var actual = int(base_points * combo_mult)
	score += actual
	mission_scores[current_mission] = mission_scores.get(current_mission, 0) + actual
	score_changed.emit(score)
	combo_changed.emit(combo_streak, combo_mult)
	# Play combo sound if streak hits 3+
	if combo_streak >= 3:
		var am = get_node_or_null("/root/AudioManager")
		if am: am.play("combo")
	return actual

func lose_life():
	combo_streak = 0
	combo_mult   = 1.0
	lives        = max(0, lives - 1)
	lives_changed.emit(lives)
	combo_changed.emit(combo_streak, combo_mult)

func reset_combo():
	combo_streak = 0
	combo_mult   = 1.0
	combo_changed.emit(combo_streak, combo_mult)

func _update_mult():
	if combo_streak >= 8:
		combo_mult = 3.0
	elif combo_streak >= 5:
		combo_mult = 2.0
	elif combo_streak >= 3:
		combo_mult = 1.5
	else:
		combo_mult = 1.0

func complete_mission(n: int):
	if n not in missions_completed:
		missions_completed.append(n)
	current_mission = n + 1
	reset_combo()
	var am = get_node_or_null("/root/AudioManager")
	if am: am.play("level_up")

func get_rank() -> String:
	var pct = (float(score) / 350.0) * 100.0
	if pct >= 90: return "Elite Guardian"
	elif pct >= 75: return "Senior Agent"
	elif pct >= 50: return "Agent"
	return "Rookie"

func get_rank_color() -> String:
	match get_rank():
		"Elite Guardian": return "#FFD700"
		"Senior Agent":   return "#1D9E75"
		"Agent":          return "#378ADD"
		_:                return "#E24B4A"

func is_mission_unlocked(n: int) -> bool:
	if n == 1: return true
	return (n - 1) in missions_completed

func reset_game():
	score           = 0
	lives           = SettingsManager.get_lives() if SettingsManager else 3
	current_mission = 1
	combo_streak    = 0
	combo_mult      = 1.0
	missions_completed.clear()
	mission_scores  = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0}
