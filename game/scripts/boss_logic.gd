extends Control

# ─────────────────────────────────────────────────────────────────────────────
#  Threat data
# ─────────────────────────────────────────────────────────────────────────────
const THREATS = [
	{type="EMAIL",    col="#E24B4A", icon="@",
	 threat="THREAT 1 — PHISHING EMAIL\nFrom: paypa1-secure@win.net\nSubject: URGENT — Account Suspended\nVerify your details immediately or lose access!",
	 question="What should Alex do with this email?",
	 options=["Click the link and verify details",
			  "Delete it — paypa1 is a fake domain",
			  "Reply asking if it is real",
			  "Forward it to friends"],
	 correct=1,
	 explanation="paypa1 uses the number 1 not the letter l.\nThis is phishing — delete it immediately!"},

	{type="PASS",     col="#EF9F27", icon="#",
	 threat="THREAT 2 — WEAK PASSWORD\nAlex wants to use: password123\nfor their new bank account.",
	 question="Is this password strong enough for a bank account?",
	 options=["Yes — it has numbers and letters",
			  "No — it's one of the most common passwords",
			  "Yes — it is long enough",
			  "No — it only needs one more symbol"],
	 correct=1,
	 explanation="password123 is one of the most hacked passwords.\nA bank needs uppercase, numbers, symbols and no common words!"},

	{type="WEBSITE",  col="#9B59B6", icon="W",
	 threat="THREAT 3 — FAKE WEBSITE\nAlex is about to log in at:\nhttp://faceb00k-login.com",
	 question="What is wrong with this website?",
	 options=["Nothing — it looks like Facebook",
			  "URL uses zeros not letter o, and no https",
			  "The site is too slow to load",
			  "Facebook sometimes uses different domains"],
	 correct=1,
	 explanation="faceb00k uses zeros — typosquatting!\nAlso no https = no secure connection. Stay away!"},

	{type="SMS",      col="#1D9E75", icon="!",
	 threat="THREAT 4 — SMISHING TEXT\nUnknown: You won an iPhone!\nClaim within 1 hour at prize-claim99.net",
	 question="What should Alex do with this text?",
	 options=["Click quickly before the hour is up",
			  "Share it on social media",
			  "Delete it — Alex never entered a competition",
			  "Reply to find out more"],
	 correct=2,
	 explanation="Alex never entered a competition.\nprize-claim99.net is fake. Delete it!"},

	{type="EMAIL",    col="#E24B4A", icon="@",
	 threat="THREAT 5 — BANK PHISHING\nFrom: security@natwest-alerts.co.uk\nUnusual activity — click to verify:\nnatwest-alerts.co.uk/verify",
	 question="How should Alex handle this security alert?",
	 options=["Click the link immediately",
			  "Call the number on the back of your bank card",
			  "Reply with account details",
			  "Ignore it completely"],
	 correct=1,
	 explanation="natwest-alerts.co.uk is NOT natwest.com.\nNever click links — call the number on your bank card!"},

	{type="PASS",     col="#EF9F27", icon="#",
	 threat="THREAT 6 — PASSWORD REUSE\nAlex uses Summer2024!\nfor email, Instagram AND banking.",
	 question="What is the main problem here?",
	 options=["Summer2024! is not strong enough",
			  "One breach exposes all accounts — reuse is dangerous",
			  "Social media needs different passwords",
			  "The password is too short"],
	 correct=1,
	 explanation="Password reuse is deadly.\nIf one site is hacked, all your accounts fall. Use unique passwords!"},

	{type="TECH",     col="#FF69B4", icon="⚠",
	 threat="THREAT 7 — TECH SCAM\nAlex sees a pop-up:\nMICROSOFT SUPPORT ALERT\nVirus detected! Call 0800 999 888 NOW!",
	 question="What is this and what should Alex do?",
	 options=["Call the number immediately",
			  "This is a tech support scam — close the browser",
			  "Download the antivirus shown",
			  "Give remote access to fix it"],
	 correct=1,
	 explanation="Microsoft NEVER shows pop-ups asking you to call.\nClose your browser and never give remote access to strangers!"},
]

# ─────────────────────────────────────────────────────────────────────────────
#  State
# ─────────────────────────────────────────────────────────────────────────────
var _idx:        int  = 0
var _can_answer: bool = false
var _time_left:  int  = 90
var _timer_tick: Timer
var _timer_on:   bool = false
var _max_lives:  int  = 3   # set in _ready before signals connect

# UI references (built in code — scene nodes only used as anchors)
var _arena:        Control
var _quiz:         Control
var _threat_icon:  Control
var _alex:         Control
var _lives_lbl:    Label
var _score_lbl:    Label
var _timer_lbl:    Label
var _combo_lbl:    Label
var _threat_txt:   Label
var _question_lbl: Label
var _feedback_lbl: Label
var _opt_btns:     Array = []
var _threat_tween: Tween
var _overlay:      ColorRect

func _ready():
	_max_lives = GameManager.lives   # capture BEFORE any signal fires
	_create_overlay()
	_build_full_ui()
	_setup_timer()
	GameManager.combo_changed.connect(_on_combo_changed)
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.lives_changed.connect(_on_lives_changed)
	StyleManager.add_back_button(self)
	_fade_in()
	_load_threat()

# ─────────────────────────────────────────────────────────────────────────────
#  Overlay
# ─────────────────────────────────────────────────────────────────────────────
func _create_overlay():
	_overlay = ColorRect.new()
	_overlay.color = Color(0.04, 0.08, 0.14, 1.0)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.z_index = 100; _overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)

func _fade_in():
	var tw = create_tween(); tw.set_ease(Tween.EASE_OUT); tw.set_trans(Tween.TRANS_QUAD)
	tw.tween_property(_overlay, "color:a", 0.0, 0.5)

func _fade_out_to(path: String):
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw = create_tween(); tw.set_ease(Tween.EASE_IN); tw.set_trans(Tween.TRANS_QUAD)
	tw.tween_property(_overlay, "color:a", 1.0, 0.4)
	tw.tween_callback(func(): get_tree().change_scene_to_file(path))

# ─────────────────────────────────────────────────────────────────────────────
#  Full UI construction
# ─────────────────────────────────────────────────────────────────────────────
func _build_full_ui():
	# --- Background ---
	var bg = $ColorRect
	bg.color = Color("#060E1C")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Grid overlay
	StyleManager.style_scene(self, "#8B2500")

	# ═══════════ TOP: ARENA (0-280) ═══════════
	_arena = _make_panel_bg(0, 0, 1152, 280, "#0D1520", "#8B2500")
	_arena.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Arena title bar
	var arena_title = Label.new()
	arena_title.text = "◼  CYBER ARENA  ◼"
	arena_title.add_theme_font_size_override("font_size", 14)
	arena_title.add_theme_color_override("font_color", Color("#E24B4A"))
	arena_title.position = Vector2(480, 8)
	arena_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arena.add_child(arena_title)
	add_child(_arena)

	# Alex (left of arena)
	_alex = StyleManager.make_alex(_arena, 30, -30, "worried")
	_alex.scale = Vector2(0.65, 0.65)

	# HUD bar
	var hud = _make_panel_bg(0, 235, 1152, 48, "#0A1520", "#185FA5")
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)

	var _init_hearts = ""; for _i in range(GameManager.lives): _init_hearts += "❤ "
	_lives_lbl = _hud_label(hud, 20, 10, _init_hearts.strip_edges(), Color("#E24B4A"), 19)
	_score_lbl = _hud_label(hud, 260,  10, "Score: 0",    Color("#FFD700"), 19)
	_timer_lbl = _hud_label(hud, 530,  6,  "⏱  90s",      Color("#1D9E75"), 24)
	_combo_lbl = _hud_label(hud, 780,  10, "Combo: x1",   Color("#00FFFF"), 19)

	# Mission label
	var m_lbl = _hud_label(hud, 940, 10, "BOSS  5/5",   Color("#EF9F27"), 16)

	# ═══════════ BOTTOM: QUIZ PANEL (283-648) ═══════════
	_quiz = _make_panel_bg(0, 283, 1152, 365, "#060E1C", "#185FA5")
	add_child(_quiz)

	# Threat text box
	var threat_bg = _make_panel_bg(18, 12, 680, 88, "#0D1826", "#E24B4A")
	threat_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quiz.add_child(threat_bg)
	_threat_txt = Label.new()
	_threat_txt.position = Vector2(26, 20)
	_threat_txt.custom_minimum_size = Vector2(660, 0)
	_threat_txt.add_theme_font_size_override("font_size", 14)
	_threat_txt.add_theme_color_override("font_color", Color("#FFB3B3"))
	_threat_txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_threat_txt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	threat_bg.add_child(_threat_txt)

	# Progress indicator (right of threat box)
	var prog_bg = _make_panel_bg(716, 12, 200, 88, "#0D1826", "#EF9F27")
	prog_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quiz.add_child(prog_bg)
	var prog_lbl = Label.new()
	prog_lbl.text = "Threat Counter"
	prog_lbl.position = Vector2(724, 28)
	prog_lbl.add_theme_font_size_override("font_size", 12)
	prog_lbl.add_theme_color_override("font_color", Color("#4A6B8A"))
	prog_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quiz.add_child(prog_lbl)

	# Question label
	_question_lbl = Label.new()
	_question_lbl.position = Vector2(18, 112)
	_question_lbl.custom_minimum_size = Vector2(1110, 0)
	_question_lbl.add_theme_font_size_override("font_size", 18)
	_question_lbl.add_theme_color_override("font_color", Color("#EF9F27"))
	_question_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_question_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quiz.add_child(_question_lbl)

	# Answer buttons (2×2 grid)
	var btn_cols = ["#4A1500", "#1A0040", "#003015", "#3A2A00"]
	var btn_pos  = [Vector2(18, 148), Vector2(578, 148),
					Vector2(18, 208), Vector2(578, 208)]
	for i in range(4):
		var btn = Button.new()
		btn.position = btn_pos[i]
		btn.custom_minimum_size = Vector2(545, 52)
		StyleManager.style_button(btn, btn_cols[i], "#FFFFFF")
		btn.add_theme_font_size_override("font_size", 16)
		_quiz.add_child(btn)
		var ci = i
		btn.pressed.connect(func(): _check_answer(ci))
		_opt_btns.append(btn)

	# Feedback
	_feedback_lbl = Label.new()
	_feedback_lbl.position = Vector2(18, 275)
	_feedback_lbl.custom_minimum_size = Vector2(1110, 50)
	_feedback_lbl.add_theme_font_size_override("font_size", 15)
	_feedback_lbl.add_theme_color_override("font_color", Color("#1D9E75"))
	_feedback_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quiz.add_child(_feedback_lbl)

# ─────────────────────────────────────────────────────────────────────────────
#  Timer
# ─────────────────────────────────────────────────────────────────────────────
func _setup_timer():
	_time_left = SettingsManager.get_boss_time() if SettingsManager else 90
	_timer_tick = Timer.new(); _timer_tick.wait_time = 1.0
	_timer_tick.autostart = true; _timer_tick.timeout.connect(_tick)
	add_child(_timer_tick); _timer_on = true

func _tick():
	if not _timer_on: return
	_time_left -= 1
	var col = Color("#1D9E75")
	if _time_left <= 30: col = Color("#EF9F27")
	if _time_left <= 10: col = Color("#E24B4A")
	_timer_lbl.text = "⏱  " + str(_time_left) + "s"
	_timer_lbl.add_theme_color_override("font_color", col)
	if _time_left <= 10:
		var am = get_node_or_null("/root/AudioManager")
		if am: am.play("tick")
	if _time_left <= 0:
		_timer_on = false; _time_up()

func _time_up():
	_feedback_lbl.text = "⏱  TIME IS UP! Moving to results..."
	_feedback_lbl.add_theme_color_override("font_color", Color("#E24B4A"))
	StyleManager.screen_flash(self, Color("#FF0000"))
	for b in _opt_btns: b.disabled = true
	var am = get_node_or_null("/root/AudioManager")
	if am: am.play("game_over")
	await get_tree().create_timer(2.2).timeout
	_go_results()

# ─────────────────────────────────────────────────────────────────────────────
#  Threat loading  (loads threat data AND spawns the arena icon)
# ─────────────────────────────────────────────────────────────────────────────
func _load_threat():
	if _idx >= THREATS.size():
		_timer_on = false; _timer_tick.stop(); _go_results(); return

	_can_answer = false
	_feedback_lbl.text = ""
	for b in _opt_btns: b.disabled = false

	var t = THREATS[_idx]

	# Update labels
	_threat_txt.text   = t["threat"]
	_question_lbl.text = t["question"]
	_score_lbl.text    = "Score: " + str(GameManager.score)

	var letters = ["A", "B", "C", "D"]
	for i in range(4):
		_opt_btns[i].text = letters[i] + ")  " + t["options"][i]
		_opt_btns[i].add_theme_color_override("font_color", Color("#FFFFFF"))

	# Spawn arena threat icon
	if is_instance_valid(_threat_icon):
		_threat_icon.queue_free()
	_threat_icon = _spawn_threat_icon(t)

	# Animate icon flying toward Alex
	if _threat_tween and _threat_tween.is_valid():
		_threat_tween.kill()
	_threat_tween = create_tween()
	_threat_tween.set_ease(Tween.EASE_IN_OUT)
	_threat_tween.set_trans(Tween.TRANS_CUBIC)
	_threat_tween.tween_property(_threat_icon, "position:x", 220.0, 6.5)
	_threat_tween.tween_callback(func():
		# Threat reached Alex — auto-resolve as miss if not answered
		if not _can_answer: return
		_can_answer = false
		GameManager.lose_life()
		_on_wrong_answer()
		_threat_hit_alex()
	)

	# Short delay then allow answering
	await get_tree().create_timer(0.3).timeout
	_can_answer = true

func _spawn_threat_icon(t: Dictionary) -> Control:
	var ic = Control.new()
	ic.position = Vector2(1020, 60)
	_arena.add_child(ic)

	# Glowing circle
	var glow = ColorRect.new()
	glow.color = Color(t["col"]); glow.color.a = 0.18
	glow.size = Vector2(110, 110); glow.position = Vector2(-8, -8)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE; ic.add_child(glow)
	var gtw = glow.create_tween(); gtw.set_loops(); gtw.set_trans(Tween.TRANS_SINE)
	gtw.tween_property(glow, "color:a", 0.55, 0.5)
	gtw.tween_property(glow, "color:a", 0.12, 0.5)

	# Icon body
	var body = ColorRect.new()
	body.color = Color(t["col"]); body.color.a = 0.6
	body.size  = Vector2(94, 94); body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.add_child(body)

	# Type letter
	var lbl = Label.new()
	lbl.text = t["icon"]
	lbl.add_theme_font_size_override("font_size", 46)
	lbl.add_theme_color_override("font_color", Color("#FFFFFF"))
	lbl.position = Vector2(18, 14); lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.add_child(lbl)

	# Type name tag
	var type_lbl = Label.new()
	type_lbl.text = t["type"]
	type_lbl.add_theme_font_size_override("font_size", 12)
	type_lbl.add_theme_color_override("font_color", Color(t["col"]))
	type_lbl.position = Vector2(-4, 98); type_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.add_child(type_lbl)

	return ic

# ─────────────────────────────────────────────────────────────────────────────
#  Answer checking
# ─────────────────────────────────────────────────────────────────────────────
func _check_answer(idx: int):
	if not _can_answer: return
	_can_answer = false

	if _threat_tween and _threat_tween.is_valid():
		_threat_tween.kill()

	var t       = THREATS[_idx]
	var correct = (idx == t["correct"])

	for b in _opt_btns: b.disabled = true
	_opt_btns[idx].add_theme_color_override("font_color",
		Color("#1DFF88") if correct else Color("#FF4444"))
	if not correct:
		_opt_btns[t["correct"]].add_theme_color_override("font_color", Color("#1DFF88"))

	var icon_pos = _get_icon_center()

	if correct:
		var pts = GameManager.add_score(20)
		_feedback_lbl.text = "CORRECT!  +" + str(pts) + " pts\n" + t["explanation"]
		_feedback_lbl.add_theme_color_override("font_color", Color("#1DFF88"))
		StyleManager.screen_flash(self, Color("#00FF66"))
		StyleManager.spawn_correct_particles(_arena, icon_pos)
		StyleManager.spawn_score_popup(_arena, icon_pos, pts, true)
		if GameManager.combo_streak >= 3:
			StyleManager.spawn_combo_banner(self, GameManager.combo_streak, GameManager.combo_mult)
		StyleManager.alex_celebrate(_alex)
		_explode_icon()
		var am = get_node_or_null("/root/AudioManager")
		if am: am.play("correct")
	else:
		GameManager.lose_life()
		_feedback_lbl.text = "WRONG!  -1 life\nCorrect: " \
			+ t["options"][t["correct"]] + "\n" + t["explanation"]
		_feedback_lbl.add_theme_color_override("font_color", Color("#FF4444"))
		StyleManager.screen_flash(self, Color("#FF0000"))
		StyleManager.spawn_score_popup(_arena, icon_pos, 1, false)
		StyleManager.alex_sad(_alex)
		_on_wrong_answer()
		_threat_hit_alex()
		var am = get_node_or_null("/root/AudioManager")
		if am: am.play("wrong")

	_score_lbl.text = "Score: " + str(GameManager.score)

	if GameManager.lives <= 0:
		await get_tree().create_timer(2.2).timeout
		_timer_on = false; _timer_tick.stop(); _go_results(); return

	await get_tree().create_timer(3.0).timeout
	_idx += 1
	_load_threat()

func _on_wrong_answer():
	_update_lives_display()

func _update_lives_display():
	var hearts = ""
	for i in range(GameManager.lives):            hearts += "❤ "
	for i in range(_max_lives - GameManager.lives): hearts += "♡ "
	_lives_lbl.text = hearts.strip_edges()

# ─────────────────────────────────────────────────────────────────────────────
#  Arena icon animations
# ─────────────────────────────────────────────────────────────────────────────
func _explode_icon():
	if not is_instance_valid(_threat_icon): return
	var pos = _get_icon_center()
	# Expand + fade
	var tw = _threat_icon.create_tween()
	tw.set_ease(Tween.EASE_OUT); tw.set_trans(Tween.TRANS_BACK)
	tw.tween_property(_threat_icon, "scale", Vector2(2.0, 2.0), 0.25)
	tw.parallel().tween_property(_threat_icon, "modulate:a", 0.0, 0.25)
	tw.tween_callback(_threat_icon.queue_free)

func _threat_hit_alex():
	if not is_instance_valid(_threat_icon): return
	# Slide icon to Alex and fade
	var tw = _threat_icon.create_tween()
	tw.set_ease(Tween.EASE_IN); tw.set_trans(Tween.TRANS_QUAD)
	tw.tween_property(_threat_icon, "position:x", 40.0, 0.35)
	tw.parallel().tween_property(_threat_icon, "modulate:a", 0.0, 0.35)
	tw.tween_callback(_threat_icon.queue_free)

func _get_icon_center() -> Vector2:
	if is_instance_valid(_threat_icon):
		return _threat_icon.position + Vector2(47, 47)
	return Vector2(576, 140)

# ─────────────────────────────────────────────────────────────────────────────
#  Signal handlers
# ─────────────────────────────────────────────────────────────────────────────
func _on_combo_changed(streak: int, mult: float):
	if streak >= 2:
		_combo_lbl.text = "Combo: x" + str(snappedf(mult, 0.5)).trim_suffix(".0") + "!"
		_combo_lbl.add_theme_color_override("font_color", Color("#FFD700"))
	else:
		_combo_lbl.text = "Combo: x1"
		_combo_lbl.add_theme_color_override("font_color", Color("#00FFFF"))

func _on_score_changed(new_score: int):
	_score_lbl.text = "Score: " + str(new_score)

func _on_lives_changed(new_lives: int):
	var hearts = ""
	for i in range(new_lives):              hearts += "❤ "
	for i in range(_max_lives - new_lives): hearts += "♡ "
	_lives_lbl.text = hearts.strip_edges()

# ─────────────────────────────────────────────────────────────────────────────
#  Navigation
# ─────────────────────────────────────────────────────────────────────────────
func _go_results():
	GameManager.complete_mission(5)
	_fade_out_to("res://scenes/results.tscn")

# ─────────────────────────────────────────────────────────────────────────────
#  Helpers
# ─────────────────────────────────────────────────────────────────────────────
static func _make_panel_bg(x: float, y: float, w: float, h: float,
						   bg: String, border: String) -> Control:
	var c = Control.new()
	c.position = Vector2(x, y)
	var rect = ColorRect.new()
	rect.color = Color(bg); rect.size = Vector2(w, h)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE; c.add_child(rect)
	var bord = ColorRect.new()
	bord.color = Color(border); bord.color.a = 0.6
	bord.size  = Vector2(w, 3)
	bord.mouse_filter = Control.MOUSE_FILTER_IGNORE; c.add_child(bord)
	var bord2 = ColorRect.new()
	bord2.color = Color(border); bord2.color.a = 0.6
	bord2.position = Vector2(0, h - 3); bord2.size = Vector2(w, 3)
	bord2.mouse_filter = Control.MOUSE_FILTER_IGNORE; c.add_child(bord2)
	return c

static func _hud_label(parent: Control, x: float, y: float,
					   txt: String, col: Color, size: int) -> Label:
	var lbl = Label.new()
	lbl.text = txt; lbl.position = Vector2(x, y)
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", col)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(lbl)
	return lbl
