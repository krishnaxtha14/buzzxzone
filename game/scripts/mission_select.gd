extends Control

const MISSIONS = [
	{name="EMAIL",    title="Mission 1\nSuspicious Inbox",   scene="res://scenes/mission_inbox.tscn",    col="#E24B4A", icon="@"},
	{name="PASSWORD", title="Mission 2\nHacked Account",     scene="res://scenes/mission_password.tscn", col="#EF9F27", icon="#"},
	{name="WEBSITE",  title="Mission 3\nFake Website",       scene="res://scenes/mission_website.tscn",  col="#9B59B6", icon="W"},
	{name="SMS",      title="Mission 4\nUrgent Text",        scene="res://scenes/mission_sms.tscn",      col="#1D9E75", icon="!"},
	{name="BOSS",     title="Mission 5\nFinal Guardian",     scene="res://scenes/mission_boss.tscn",     col="#E24B4A", icon="X"},
]

var _overlay: ColorRect
var _node_btns: Array = []

func _ready():
	_create_overlay()
	_build_background()
	_build_header()
	_build_mission_nodes()
	_build_race_button()
	_build_score_bar()
	_fade_in()

func _create_overlay():
	_overlay = ColorRect.new()
	_overlay.color = Color(0.04, 0.08, 0.14, 1.0)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.z_index = 100; _overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)

func _fade_in():
	var tw = create_tween(); tw.set_ease(Tween.EASE_OUT); tw.set_trans(Tween.TRANS_QUAD)
	tw.tween_property(_overlay, "color:a", 0.0, 0.55)

func _fade_out_then(path: String):
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw = create_tween(); tw.set_ease(Tween.EASE_IN); tw.set_trans(Tween.TRANS_QUAD)
	tw.tween_property(_overlay, "color:a", 1.0, 0.38)
	tw.tween_callback(func(): get_tree().change_scene_to_file(path))

# ─────────────────────────────────────────────────────────────────────────────
#  Background
# ─────────────────────────────────────────────────────────────────────────────
func _build_background():
	StyleManager.style_scene(self, "#185FA5")

# ─────────────────────────────────────────────────────────────────────────────
#  Header
# ─────────────────────────────────────────────────────────────────────────────
func _build_header():
	var title = Label.new()
	title.text = "MISSION SELECT"
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color("#FFFFFF"))
	title.position = Vector2(340, 30)
	add_child(title)

	var sub = Label.new()
	sub.text = "Choose your next mission — complete them in order to unlock the Boss!"
	sub.add_theme_font_size_override("font_size", 15)
	sub.add_theme_color_override("font_color", Color("#4A6B8A"))
	sub.position = Vector2(210, 88)
	add_child(sub)

	# Score / lives display
	var hud = HBoxContainer.new()
	hud.position = Vector2(860, 34)
	hud.add_theme_constant_override("separation", 24)
	add_child(hud)

	var score_lbl = Label.new()
	score_lbl.text = "Score: " + str(GameManager.score)
	score_lbl.add_theme_font_size_override("font_size", 18)
	score_lbl.add_theme_color_override("font_color", Color("#FFD700"))
	hud.add_child(score_lbl)

	var lives_lbl = Label.new()
	var hearts = ""
	for i in range(GameManager.lives): hearts += "❤ "
	lives_lbl.text = hearts.strip_edges()
	lives_lbl.add_theme_font_size_override("font_size", 18)
	lives_lbl.add_theme_color_override("font_color", Color("#E24B4A"))
	hud.add_child(lives_lbl)

	# Back to menu
	var back = Button.new()
	back.text = "← Menu"
	back.position = Vector2(26, 26)
	back.custom_minimum_size = Vector2(110, 38)
	StyleManager.style_button(back, "#1A2A4A", "#85B7EB")
	back.add_theme_font_size_override("font_size", 15)
	add_child(back)
	back.pressed.connect(func(): _fade_out_then("res://scenes/main_menu.tscn"))

# ─────────────────────────────────────────────────────────────────────────────
#  5 Mission nodes + connecting path
# ─────────────────────────────────────────────────────────────────────────────
func _build_mission_nodes():
	var node_xs = [100, 290, 500, 710, 920]
	var node_y  = 320

	# Draw connecting lines BEHIND nodes
	for i in range(node_xs.size() - 1):
		_draw_connect_line(Vector2(node_xs[i] + 68, node_y),
						   Vector2(node_xs[i + 1], node_y), i)

	# Build each node
	for i in range(MISSIONS.size()):
		var m        = MISSIONS[i]
		var unlocked = GameManager.is_mission_unlocked(i + 1)
		var done     = (i + 1) in GameManager.missions_completed
		var is_next  = (i + 1 == GameManager.current_mission)
		var nd = _build_node(m, node_xs[i], node_y - 80, unlocked, done, is_next, i)
		_node_btns.append(nd)
		# Staggered entrance
		nd.modulate.a = 0.0
		nd.position.y += 40
		var tw = nd.create_tween(); tw.set_ease(Tween.EASE_OUT); tw.set_trans(Tween.TRANS_BACK)
		tw.tween_interval(i * 0.12)
		tw.tween_property(nd, "modulate:a", 1.0,          0.4)
		tw.parallel().tween_property(nd, "position:y", nd.position.y - 40, 0.4)

func _draw_connect_line(from: Vector2, to: Vector2, idx: int):
	var line = ColorRect.new()
	line.color = Color("#1E3A5F"); line.color.a = 0.7
	var mid_y = from.y + 10
	line.position = Vector2(from.x, mid_y)
	line.size = Vector2(to.x - from.x, 4)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(line)

	# Animated "data packet" traveling the line
	var packet = ColorRect.new()
	packet.color = Color("#00FFFF"); packet.color.a = 0.9
	packet.size = Vector2(12, 4); packet.position = line.position
	packet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(packet)
	var tw = packet.create_tween(); tw.set_loops()
	tw.tween_property(packet, "position:x", to.x - 12, randf_range(1.0, 2.0))
	tw.tween_callback(func(): packet.position.x = from.x)

func _build_node(m: Dictionary, x: float, y: float,
				unlocked: bool, done: bool, is_next: bool, idx: int) -> Control:
	var container = Control.new()
	container.position = Vector2(x, y)
	add_child(container)

	# 3D depth shadow (offset dark copy behind the card)
	var shadow = ColorRect.new()
	shadow.color    = Color(0, 0, 0, 0.55 if unlocked else 0.25)
	shadow.size     = Vector2(148, 148)
	shadow.position = Vector2(8, 10)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(shadow)

	# Outer ring glow
	var glow = ColorRect.new()
	glow.color = Color(m["col"]); glow.color.a = 0.15 if unlocked else 0.05
	glow.position = Vector2(-12, -12); glow.size = Vector2(160, 160)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(glow)
	if unlocked:
		var gtw = glow.create_tween(); gtw.set_loops(); gtw.set_trans(Tween.TRANS_SINE)
		gtw.tween_property(glow, "color:a", 0.28, 1.2)
		gtw.tween_property(glow, "color:a", 0.08, 1.2)

	# Node circle
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(136, 136)
	var ns = StyleBoxFlat.new()
	if done:
		ns.bg_color = Color(m["col"]); ns.bg_color.a = 0.55
	elif unlocked:
		ns.bg_color = Color("#0D1B2A"); ns.bg_color.a = 0.9
	else:
		ns.bg_color = Color("#0A0A14"); ns.bg_color.a = 0.85
	ns.border_color = Color(m["col"]) if unlocked else Color("#333355")
	ns.set_border_width_all(3 if unlocked else 1)
	ns.set_corner_radius_all(68)
	ns.content_margin_left = 12; ns.content_margin_right  = 12
	ns.content_margin_top  = 12; ns.content_margin_bottom = 12
	ns.shadow_color  = Color(0, 0, 0, 0.6 if unlocked else 0.2)
	ns.shadow_size   = 8 if unlocked else 3
	ns.shadow_offset = Vector2(4, 5)
	btn.add_theme_stylebox_override("normal", ns)

	var hs: StyleBoxFlat = ns.duplicate() as StyleBoxFlat
	hs.bg_color = Color(m["col"]); hs.bg_color.a = 0.4
	btn.add_theme_stylebox_override("hover", hs)

	var icon_lbl = Label.new()
	icon_lbl.text = m["icon"]
	icon_lbl.add_theme_font_size_override("font_size", 42)
	icon_lbl.add_theme_color_override("font_color",
		Color(m["col"]) if unlocked else Color("#333366"))
	icon_lbl.position = Vector2(36, 22); icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(icon_lbl)

	if done:
		var check = Label.new()
		check.text = "✓"; check.position = Vector2(88, 8)
		check.add_theme_font_size_override("font_size", 22)
		check.add_theme_color_override("font_color", Color("#FFD700"))
		check.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(check)

	container.add_child(btn)
	btn.disabled = not unlocked

	if is_next:
		var ptw = btn.create_tween(); ptw.set_loops(); ptw.set_trans(Tween.TRANS_SINE)
		ptw.tween_property(btn, "scale", Vector2(1.06, 1.06), 0.7)
		ptw.tween_property(btn, "scale", Vector2(1.0,  1.0),  0.7)

	# Label under node
	var name_lbl = Label.new()
	name_lbl.text = m["title"]
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color",
		Color(m["col"]) if unlocked else Color("#444466"))
	name_lbl.position = Vector2(-10, 145)
	name_lbl.custom_minimum_size = Vector2(156, 0)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	container.add_child(name_lbl)

	# Score badge
	var pts = GameManager.mission_scores.get(idx + 1, 0)
	if pts > 0:
		var score_lbl = Label.new()
		score_lbl.text = "+" + str(pts) + " pts"
		score_lbl.add_theme_font_size_override("font_size", 13)
		score_lbl.add_theme_color_override("font_color", Color("#FFD700"))
		score_lbl.position = Vector2(28, 185)
		container.add_child(score_lbl)

	if unlocked:
		btn.mouse_entered.connect(func():
			var tw = btn.create_tween()
			tw.set_trans(Tween.TRANS_BACK); tw.set_ease(Tween.EASE_OUT)
			tw.tween_property(btn, "scale", Vector2(1.08, 1.08), 0.12)
			var am = get_node_or_null("/root/AudioManager")
			if am: am.play("hover")
		)
		btn.mouse_exited.connect(func():
			var tw = btn.create_tween()
			tw.set_trans(Tween.TRANS_BACK); tw.set_ease(Tween.EASE_OUT)
			tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.12)
		)
		var scene_path = m["scene"]
		btn.pressed.connect(func(): _go_to(scene_path))

	return container

# ─────────────────────────────────────────────────────────────────────────────
#  Bottom score progress bar
# ─────────────────────────────────────────────────────────────────────────────
func _build_race_button():
	var race_bg = ColorRect.new()
	race_bg.color = Color("#0A0515"); race_bg.color.a = 0.92
	race_bg.position = Vector2(0, 506); race_bg.size = Vector2(1152, 70)
	race_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(race_bg)

	var race_sep = ColorRect.new()
	race_sep.color = Color("#9B59B6"); race_sep.position = Vector2(0, 506)
	race_sep.size = Vector2(1152, 3); race_sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(race_sep)

	var race_lbl = Label.new()
	race_lbl.text = "🏎  BONUS MODE:"
	race_lbl.position = Vector2(14, 519)
	race_lbl.add_theme_font_size_override("font_size", 15)
	race_lbl.add_theme_color_override("font_color", Color("#DD88FF"))
	add_child(race_lbl)

	var race_desc = Label.new()
	race_desc.text = "Cyber Racer — dodge cars, collect 🪙 coins & answer cybersecurity questions! Coins buy new cars."
	race_desc.position = Vector2(178, 512)
	race_desc.custom_minimum_size = Vector2(598, 48)
	race_desc.size = Vector2(598, 48)
	race_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	race_desc.add_theme_font_size_override("font_size", 13)
	race_desc.add_theme_color_override("font_color", Color("#85B7EB"))
	add_child(race_desc)

	var race_btn = Button.new()
	race_btn.text = "  🏎 PLAY RACE GAME  "
	race_btn.position = Vector2(790, 521)
	race_btn.custom_minimum_size = Vector2(194, 40)
	StyleManager.style_button(race_btn, "#9B59B6", "#FFFFFF")
	race_btn.add_theme_font_size_override("font_size", 14)
	add_child(race_btn)
	race_btn.pressed.connect(func(): _go_to("res://scenes/race_3d.tscn"))

	var quit_ms = Button.new()
	quit_ms.text = "✕ Quit"
	quit_ms.position = Vector2(1002, 521)
	quit_ms.custom_minimum_size = Vector2(130, 40)
	StyleManager.style_button(quit_ms, "#2A0A0A", "#CC6666")
	quit_ms.add_theme_font_size_override("font_size", 14)
	add_child(quit_ms)
	quit_ms.pressed.connect(get_tree().quit)

func _build_score_bar():
	var bar_bg = ColorRect.new()
	bar_bg.color = Color("#0D1B2A"); bar_bg.color.a = 0.9
	bar_bg.position = Vector2(0, 576); bar_bg.size = Vector2(1152, 72)
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(bar_bg)

	var sep = ColorRect.new()
	sep.color = Color("#185FA5"); sep.position = Vector2(0, 576)
	sep.size  = Vector2(1152, 3); sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sep)

	var rank_lbl = Label.new()
	rank_lbl.text = "Rank: " + GameManager.get_rank() + "   Race Coins: 🪙 " + str(SettingsManager.race_coins if SettingsManager else 0)
	rank_lbl.position = Vector2(34, 588)
	rank_lbl.add_theme_font_size_override("font_size", 17)
	rank_lbl.add_theme_color_override("font_color", Color(GameManager.get_rank_color()))
	add_child(rank_lbl)

	var pct = clampf(float(GameManager.score) / 400.0, 0.0, 1.0)
	var pbar_bg = ColorRect.new()
	pbar_bg.color = Color("#1A2A3A"); pbar_bg.position = Vector2(400, 596)
	pbar_bg.size  = Vector2(500, 22); pbar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pbar_bg)
	var pfill = ColorRect.new()
	pfill.color    = Color(GameManager.get_rank_color())
	pfill.position = Vector2(400, 596); pfill.size = Vector2(0, 22)
	pfill.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(pfill)
	var ptw = pfill.create_tween(); ptw.set_ease(Tween.EASE_OUT)
	ptw.tween_property(pfill, "size:x", 500.0 * pct, 0.8)

	var pct_lbl = Label.new()
	pct_lbl.text = str(int(pct * 100)) + "% to Elite Guardian"
	pct_lbl.position = Vector2(916, 596)
	pct_lbl.add_theme_font_size_override("font_size", 13)
	pct_lbl.add_theme_color_override("font_color", Color("#85B7EB"))
	add_child(pct_lbl)

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()

func _go_to(path: String):
	StyleManager.screen_flash(self, Color("#00FFFF"))
	await get_tree().create_timer(0.12).timeout
	_fade_out_then(path)
