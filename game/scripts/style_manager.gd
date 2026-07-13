extends Node

# ─────────────────────────────────────────────────────────────────────────────
#  Scene background + grid
# ─────────────────────────────────────────────────────────────────────────────
static func style_scene(root: Control, mission_color: String = "#185FA5"):
	if root.has_node("ColorRect"):
		root.get_node("ColorRect").color = Color("#0A1628")
		root.get_node("ColorRect").set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root.get_node("ColorRect").mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Apply theme tint from SettingsManager if available
	var sm = root.get_node_or_null("/root/SettingsManager")
	var grid_col = mission_color
	if sm:
		var tc = sm.get_theme_colors()
		grid_col = tc.get("primary", mission_color)

	for i in range(0, 1152, 80):
		var vline = ColorRect.new()
		vline.color = Color(grid_col); vline.color.a = 0.07
		vline.position = Vector2(i, 0); vline.size = Vector2(1, 648)
		vline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(vline)
	for i in range(0, 648, 80):
		var hline = ColorRect.new()
		hline.color = Color(grid_col); hline.color.a = 0.07
		hline.position = Vector2(0, i); hline.size = Vector2(1152, 1)
		hline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(hline)

	# Corner glows
	var glow1 = ColorRect.new()
	glow1.color = Color(grid_col); glow1.color.a = 0.07
	glow1.position = Vector2(-150, -150); glow1.size = Vector2(500, 500)
	glow1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(glow1)
	var glow2 = ColorRect.new()
	glow2.color = Color(grid_col); glow2.color.a = 0.05
	glow2.position = Vector2(700, 280); glow2.size = Vector2(600, 600)
	glow2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(glow2)

	# Accent bars
	var top = ColorRect.new()
	top.color = Color(grid_col); top.position = Vector2(0, 0); top.size = Vector2(1152, 6)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(top)
	var bot = ColorRect.new()
	bot.color = Color(grid_col); bot.position = Vector2(0, 642); bot.size = Vector2(1152, 6)
	bot.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(bot)
	var side = ColorRect.new()
	side.color = Color(grid_col); side.color.a = 0.4
	side.position = Vector2(0, 6); side.size = Vector2(5, 636)
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(side)

	var corner_lbl = Label.new()
	corner_lbl.add_theme_font_size_override("font_size", 11)
	corner_lbl.add_theme_color_override("font_color", Color(grid_col))
	corner_lbl.position = Vector2(900, 622)
	corner_lbl.text = "CYBER GUARDIAN  |  503IT"
	corner_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(corner_lbl)

	_spawn_particles(root, grid_col)

	# Scanning line that scrolls down
	_add_scan_line(root, grid_col)

static func _add_scan_line(root: Control, col: String):
	var scan = ColorRect.new()
	scan.color = Color(col); scan.color.a = 0.12
	scan.size  = Vector2(1152, 3)
	scan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(scan)
	var tw = scan.create_tween()
	tw.set_loops()
	tw.tween_property(scan, "position:y",  0.0, 0.0)
	tw.tween_property(scan, "position:y", 648.0, 3.2)
	tw.tween_callback(func(): scan.position.y = -4)

static func _spawn_particles(root: Control, mission_color: String):
	for i in range(22):
		var p = ColorRect.new()
		var sz = randf_range(3, 8)
		p.size = Vector2(sz, sz)
		p.color = Color(mission_color); p.color.a = randf_range(0.3, 0.8)
		p.position = Vector2(randf_range(0, 1152), randf_range(0, 648))
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(p)
		_animate_particle(p)

static func _animate_particle(p: ColorRect):
	var tw = p.create_tween(); tw.set_loops()
	tw.set_trans(Tween.TRANS_SINE); tw.set_ease(Tween.EASE_IN_OUT)
	var ty = p.position.y - randf_range(30, 80)
	var dur = randf_range(2.0, 5.0)
	tw.tween_property(p, "position:y", ty,                          dur)
	tw.parallel().tween_property(p, "color:a", 0.08,               dur)
	tw.tween_property(p, "position:y", p.position.y,               dur)
	tw.parallel().tween_property(p, "color:a", randf_range(0.3, 0.8), dur)

# ─────────────────────────────────────────────────────────────────────────────
#  Button styling with click animation + hover sound
# ─────────────────────────────────────────────────────────────────────────────
static func style_button(btn: Button, bg: String, fg: String = "#FFFFFF"):
	# Normal — 3D raised look with drop shadow
	var sn = StyleBoxFlat.new()
	sn.bg_color     = Color(bg); sn.set_corner_radius_all(10)
	sn.content_margin_left = 20; sn.content_margin_right  = 20
	sn.content_margin_top  = 14; sn.content_margin_bottom = 14
	sn.border_color = Color(bg).lightened(0.4); sn.set_border_width_all(2)
	# 3D drop shadow
	sn.shadow_color  = Color(0, 0, 0, 0.65)
	sn.shadow_size   = 6
	sn.shadow_offset = Vector2(3, 5)
	btn.add_theme_stylebox_override("normal", sn)

	# Hover — brighter, shadow closer (lifts forward)
	var sh = StyleBoxFlat.new()
	sh.bg_color     = Color(bg).lightened(0.22); sh.set_corner_radius_all(10)
	sh.content_margin_left = 20; sh.content_margin_right  = 20
	sh.content_margin_top  = 14; sh.content_margin_bottom = 14
	sh.border_color = Color(bg).lightened(0.55); sh.set_border_width_all(2)
	sh.shadow_color  = Color(0, 0, 0, 0.55)
	sh.shadow_size   = 9
	sh.shadow_offset = Vector2(4, 7)
	btn.add_theme_stylebox_override("hover", sh)

	# Pressed — sinks in (shadow collapses to near-zero)
	var sp = StyleBoxFlat.new()
	sp.bg_color     = Color(bg).darkened(0.18); sp.set_corner_radius_all(10)
	sp.content_margin_left = 22; sp.content_margin_right  = 22
	sp.content_margin_top  = 16; sp.content_margin_bottom = 12
	sp.shadow_color  = Color(0, 0, 0, 0.30)
	sp.shadow_size   = 2
	sp.shadow_offset = Vector2(1, 1)
	btn.add_theme_stylebox_override("pressed", sp)

	btn.add_theme_color_override("font_color",         Color(fg))
	btn.add_theme_color_override("font_hover_color",   Color(fg))
	btn.add_theme_color_override("font_pressed_color", Color(fg))
	btn.add_theme_font_size_override("font_size", 20)

	# Hover scale + sound
	btn.mouse_entered.connect(func():
		var tw = btn.create_tween()
		tw.set_trans(Tween.TRANS_BACK); tw.set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2(1.06, 1.06), 0.10)
		var am = btn.get_node_or_null("/root/AudioManager")
		if am: am.play("hover")
	)
	btn.mouse_exited.connect(func():
		var tw = btn.create_tween()
		tw.set_trans(Tween.TRANS_BACK); tw.set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.10)
	)
	# Press squish animation
	btn.button_down.connect(func():
		var tw = btn.create_tween()
		tw.set_trans(Tween.TRANS_BACK); tw.set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2(0.94, 0.94), 0.06)
	)
	btn.button_up.connect(func():
		var tw = btn.create_tween()
		tw.set_trans(Tween.TRANS_BACK); tw.set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.12)
	)

# ─────────────────────────────────────────────────────────────────────────────
#  Panel
# ─────────────────────────────────────────────────────────────────────────────
static func make_panel(panel: PanelContainer, bg: String, border: String):
	var style = StyleBoxFlat.new()
	style.bg_color     = Color(bg); style.border_color = Color(border)
	style.set_border_width_all(2); style.set_corner_radius_all(12)
	style.content_margin_left = 16; style.content_margin_right  = 16
	style.content_margin_top  = 12; style.content_margin_bottom = 12
	# 3D depth shadow
	style.shadow_color  = Color(0, 0, 0, 0.7)
	style.shadow_size   = 8
	style.shadow_offset = Vector2(5, 6)
	panel.add_theme_stylebox_override("panel", style)

# ─────────────────────────────────────────────────────────────────────────────
#  Floating score popup
# ─────────────────────────────────────────────────────────────────────────────
static func spawn_score_popup(parent: Control, pos: Vector2,
							  points: int, correct: bool):
	var lbl = Label.new()
	lbl.text = ("+" if correct else "-") + str(abs(points))
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.add_theme_color_override("font_color",
		Color("#1DFF88") if correct else Color("#FF4444"))
	lbl.position = pos - Vector2(30, 20)
	lbl.z_index  = 60
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(lbl)
	var tw = lbl.create_tween()
	tw.set_trans(Tween.TRANS_QUAD); tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "position:y", pos.y - 90, 0.7)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.7)
	tw.tween_callback(lbl.queue_free)

# ─────────────────────────────────────────────────────────────────────────────
#  Combo banner
# ─────────────────────────────────────────────────────────────────────────────
static func spawn_combo_banner(parent: Control, streak: int, mult: float):
	var lbl = Label.new()
	lbl.text = "COMBO x" + str(int(mult)) + "!  (" + str(streak) + " streak)"
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", Color("#FFD700"))
	lbl.position   = Vector2(340, 20)
	lbl.z_index    = 60
	lbl.modulate.a = 0.0
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(lbl)
	var tw = lbl.create_tween()
	tw.set_trans(Tween.TRANS_BACK); tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 1.0, 0.25)
	tw.tween_property(lbl, "scale",      Vector2(1.15, 1.15), 0.15)
	tw.tween_property(lbl, "scale",      Vector2(1.0,  1.0),  0.15)
	tw.tween_interval(1.2)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.4)
	tw.tween_callback(lbl.queue_free)

# ─────────────────────────────────────────────────────────────────────────────
#  Screen flash
# ─────────────────────────────────────────────────────────────────────────────
static func screen_flash(root: Control, color: Color):
	var flash = ColorRect.new()
	flash.color = color; flash.color.a = 0.0
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.z_index = 70; flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(flash)
	var tw = flash.create_tween()
	tw.set_trans(Tween.TRANS_QUAD)
	tw.tween_property(flash, "color:a", 0.38, 0.08)
	tw.tween_property(flash, "color:a", 0.0,  0.35)
	tw.tween_callback(flash.queue_free)

# ─────────────────────────────────────────────────────────────────────────────
#  Alex character (unchanged logic, added return ref)
# ─────────────────────────────────────────────────────────────────────────────
static func make_alex(parent: Control, x: float, y: float,
					  mood: String = "happy") -> Control:
	var alex = Control.new()
	alex.position = Vector2(x, y)
	parent.add_child(alex)

	var border_rect = ColorRect.new()
	border_rect.color    = Color("#1E3A5F")
	border_rect.position = Vector2(-2, -2)
	border_rect.size     = Vector2(204, 320)
	border_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	alex.add_child(border_rect)

	var card = ColorRect.new()
	card.color = Color("#0A1520"); card.size = Vector2(200, 316)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE; alex.add_child(card)

	var hair = ColorRect.new()
	hair.color = Color("#2C1810"); hair.position = Vector2(55, 18)
	hair.size = Vector2(90, 22); hair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	alex.add_child(hair)

	var head = ColorRect.new()
	head.color = Color("#FDBCB4"); head.position = Vector2(60, 36)
	head.size = Vector2(80, 72); head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	alex.add_child(head)

	for ex in [Vector2(73, 54), Vector2(113, 54)]:
		var eye = ColorRect.new()
		eye.color = Color("#1A1A2E"); eye.position = ex
		eye.size = Vector2(14, 14); eye.mouse_filter = Control.MOUSE_FILTER_IGNORE
		alex.add_child(eye)

	var brow_l = ColorRect.new(); var brow_r = ColorRect.new()
	brow_l.color = Color("#2C1810"); brow_r.color = Color("#2C1810")
	brow_l.size  = Vector2(16, 5);   brow_r.size  = Vector2(16, 5)
	brow_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brow_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if mood == "worried":
		brow_l.position = Vector2(71, 45); brow_r.position = Vector2(111, 45)
	else:
		brow_l.position = Vector2(73, 48); brow_r.position = Vector2(113, 48)
	alex.add_child(brow_l); alex.add_child(brow_r)

	var mouth = ColorRect.new()
	mouth.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if mood == "happy":
		mouth.color = Color("#1D9E75"); mouth.position = Vector2(78, 86)
		mouth.size  = Vector2(44, 10)
	elif mood == "worried":
		mouth.color = Color("#E24B4A"); mouth.position = Vector2(78, 90)
		mouth.size  = Vector2(44, 7)
	else:
		mouth.color = Color("#C17B6B"); mouth.position = Vector2(78, 86)
		mouth.size  = Vector2(44, 8)
	alex.add_child(mouth)

	var body = ColorRect.new()
	body.color = Color("#185FA5"); body.position = Vector2(50, 108)
	body.size = Vector2(100, 100); body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	alex.add_child(body)

	var badge = ColorRect.new()
	badge.color = Color("#1D9E75"); badge.position = Vector2(80, 128)
	badge.size  = Vector2(40, 44); badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	alex.add_child(badge)
	var badge_lbl = Label.new()
	badge_lbl.text = "CG"; badge_lbl.position = Vector2(85, 136)
	badge_lbl.add_theme_font_size_override("font_size", 13)
	badge_lbl.add_theme_color_override("font_color", Color("#FFFFFF"))
	alex.add_child(badge_lbl)

	for ar in [Vector2(18, 112), Vector2(150, 112)]:
		var arm = ColorRect.new()
		arm.color = Color("#185FA5"); arm.position = ar
		arm.size  = Vector2(32, 80); arm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		alex.add_child(arm)
	for hr in [Vector2(14, 186), Vector2(160, 186)]:
		var hand = ColorRect.new()
		hand.color = Color("#FDBCB4"); hand.position = hr
		hand.size  = Vector2(26, 26); hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
		alex.add_child(hand)

	var leg_l = ColorRect.new()
	leg_l.color = Color("#1A1A2E"); leg_l.position = Vector2(50, 208)
	leg_l.size  = Vector2(42, 70); leg_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	alex.add_child(leg_l)
	var leg_r = ColorRect.new()
	leg_r.color = Color("#1A1A2E"); leg_r.position = Vector2(108, 208)
	leg_r.size  = Vector2(42, 70); leg_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	alex.add_child(leg_r)

	for sh in [Vector2(42, 272), Vector2(104, 272)]:
		var shoe = ColorRect.new()
		shoe.color = Color("#0A0A1A"); shoe.position = sh
		shoe.size  = Vector2(54, 18); shoe.mouse_filter = Control.MOUSE_FILTER_IGNORE
		alex.add_child(shoe)

	var name_bg = ColorRect.new()
	name_bg.color = Color("#185FA5"); name_bg.position = Vector2(55, 294)
	name_bg.size  = Vector2(90, 26); name_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	alex.add_child(name_bg)
	var name_lbl = Label.new()
	name_lbl.text = "  ALEX  "; name_lbl.position = Vector2(57, 296)
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", Color("#FFFFFF"))
	alex.add_child(name_lbl)

	# Border pulse
	var bc = Color("#1D9E75") if mood == "happy" else \
			 Color("#E24B4A") if mood == "worried" else Color("#378ADD")
	var btw = border_rect.create_tween(); btw.set_loops()
	btw.set_trans(Tween.TRANS_SINE); btw.set_ease(Tween.EASE_IN_OUT)
	btw.tween_property(border_rect, "color", bc,              1.0)
	btw.tween_property(border_rect, "color", Color("#1E3A5F"), 1.0)

	# Idle bounce
	var tween = alex.create_tween(); tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE); tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(alex, "position:y", y - 10, 0.6)
	tween.tween_property(alex, "position:y", y,      0.6)

	# Leg swing
	var lt = leg_l.create_tween(); lt.set_loops(); lt.set_trans(Tween.TRANS_SINE)
	lt.tween_property(leg_l, "position:x", 55, 0.5)
	lt.tween_property(leg_l, "position:x", 45, 0.5)
	var rt = leg_r.create_tween(); rt.set_loops(); rt.set_trans(Tween.TRANS_SINE)
	rt.tween_property(leg_r, "position:x", 103, 0.5)
	rt.tween_property(leg_r, "position:x", 113, 0.5)

	# Arm wave (right arm)
	var children = alex.get_children()
	for child in children:
		if child is ColorRect and child.size == Vector2(32, 80) \
				and child.position.x > 100:
			var atw = child.create_tween(); atw.set_loops()
			atw.set_trans(Tween.TRANS_SINE)
			atw.tween_property(child, "position:y", 105, 0.4)
			atw.tween_property(child, "position:y", 112, 0.4)
			break

	return alex

static func alex_celebrate(alex: Control):
	var oy = alex.position.y
	var tw = alex.create_tween()
	tw.set_trans(Tween.TRANS_BACK); tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(alex, "scale",      Vector2(1.0, 0.8),  0.05)
	tw.tween_property(alex, "position:y", oy - 48,            0.22)
	tw.tween_property(alex, "scale",      Vector2(1.0, 1.0),  0.10)
	tw.tween_property(alex, "position:y", oy,                 0.28)
	tw.tween_property(alex, "scale",      Vector2(1.1, 0.9),  0.08)
	tw.tween_property(alex, "scale",      Vector2(1.0, 1.0),  0.14)

static func alex_sad(alex: Control):
	var ox = alex.position.x
	var tw = alex.create_tween(); tw.set_trans(Tween.TRANS_SINE)
	for i in range(5):
		tw.tween_property(alex, "position:x", ox - 9, 0.055)
		tw.tween_property(alex, "position:x", ox + 9, 0.055)
	tw.tween_property(alex, "position:x", ox, 0.055)

static func spawn_correct_particles(parent: Control, pos: Vector2):
	var colors = ["#1D9E75", "#EF9F27", "#378ADD", "#FFFFFF", "#E24B4A",
				  "#00FFFF", "#FFD700"]
	for i in range(18):
		var p = ColorRect.new()
		p.size = Vector2(7, 7)
		p.color = Color(colors[i % colors.size()])
		p.position = pos; p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(p)
		var angle = TAU * i / 18.0
		var dist  = randf_range(55, 150)
		var target = pos + Vector2(cos(angle), sin(angle)) * dist
		var tw = p.create_tween()
		tw.set_trans(Tween.TRANS_QUAD); tw.set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "position", target,  0.52)
		tw.parallel().tween_property(p, "color:a", 0.0, 0.52)
		tw.tween_callback(p.queue_free)

# ─────────────────────────────────────────────────────────────────────────────
#  Universal back button — call StyleManager.add_back_button(self) in _ready()
# ─────────────────────────────────────────────────────────────────────────────
static func add_back_button(root: Control,
							dest: String = "res://scenes/garage.tscn") -> Button:
	var btn = Button.new()
	btn.text  = "← Back"
	btn.z_index = 90
	btn.position = Vector2(12, 12)
	btn.custom_minimum_size = Vector2(110, 38)

	var sn = StyleBoxFlat.new()
	sn.bg_color     = Color("#0D1B2A"); sn.bg_color.a = 0.88
	sn.border_color = Color("#185FA5"); sn.set_border_width_all(2)
	sn.set_corner_radius_all(8)
	sn.content_margin_left = 10; sn.content_margin_right  = 10
	sn.content_margin_top  = 6;  sn.content_margin_bottom = 6
	sn.shadow_color = Color(0,0,0,0.5); sn.shadow_size = 4
	sn.shadow_offset = Vector2(2, 3)
	btn.add_theme_stylebox_override("normal", sn)

	var sh = sn.duplicate() as StyleBoxFlat
	sh.bg_color = Color("#1E3A5F"); sh.bg_color.a = 0.95
	btn.add_theme_stylebox_override("hover", sh)

	btn.add_theme_color_override("font_color", Color("#85B7EB"))
	btn.add_theme_font_size_override("font_size", 15)

	btn.mouse_entered.connect(func():
		var tw = btn.create_tween()
		tw.set_trans(Tween.TRANS_BACK); tw.set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2(1.07, 1.07), 0.10)
	)
	btn.mouse_exited.connect(func():
		var tw = btn.create_tween()
		tw.set_trans(Tween.TRANS_BACK); tw.set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.10)
	)
	btn.button_down.connect(func():
		var tw = btn.create_tween()
		tw.tween_property(btn, "scale", Vector2(0.93, 0.93), 0.06)
	)
	btn.button_up.connect(func():
		var tw = btn.create_tween()
		tw.set_trans(Tween.TRANS_BACK); tw.set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.10)
	)

	root.add_child(btn)
	btn.pressed.connect(func(): root.get_tree().change_scene_to_file(dest))
	return btn

static func transition_alex(alex_node: Control, target_x: float,
							dur: float = 1.0) -> Tween:
	var tween = alex_node.create_tween()
	tween.tween_property(alex_node, "position:x", target_x, dur)
	return tween
