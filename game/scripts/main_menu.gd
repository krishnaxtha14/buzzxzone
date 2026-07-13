extends Control

var _overlay:  ColorRect
var _title_lbl: Label
var _glitch_timer: float = 0.0
var _glitch_on:    bool  = false

func _ready():
	_create_overlay()
	_apply_theme_background()
	build_content()
	_add_gear_button()
	$VBoxContainer/Button.pressed.connect(_on_start_pressed)
	$VBoxContainer/Button2.pressed.connect(_on_howto_pressed)
	_fade_in()
	_animate_entrance()

# ─────────────────────────────────────────────────────────────────────────────
#  Overlay / fade
# ─────────────────────────────────────────────────────────────────────────────
func _create_overlay():
	_overlay = ColorRect.new()
	_overlay.color = Color(0.04, 0.08, 0.14, 1.0)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.z_index = 100
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)

func _fade_in():
	var tw = create_tween()
	tw.set_ease(Tween.EASE_OUT); tw.set_trans(Tween.TRANS_QUAD)
	tw.tween_property(_overlay, "color:a", 0.0, 0.65)

func _fade_out_then(path: String):
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw = create_tween()
	tw.set_ease(Tween.EASE_IN); tw.set_trans(Tween.TRANS_QUAD)
	tw.tween_property(_overlay, "color:a", 1.0, 0.4)
	tw.tween_callback(func(): get_tree().change_scene_to_file(path))

# ─────────────────────────────────────────────────────────────────────────────
#  Theme-aware background
# ─────────────────────────────────────────────────────────────────────────────
func _apply_theme_background():
	var tc = SettingsManager.get_theme_colors() if SettingsManager \
			 else {"bg": "#050D1A", "primary": "#00FF66",
				   "secondary": "#185FA5", "accent": "#00FFFF",
				   "rain": "#00FF66", "title_a": Color("#00FFFF"),
				   "title_b": Color("#1D9E75")}

	# CyberBackground already draws the full animated shader — don't duplicate
	# effects on top of it. Hide the flat ColorRect overlay and let the shader show.
	$ColorRect.color = Color(0, 0, 0, 0)   # fully transparent — shader is background
	$ColorRect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	$ColorRect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# CyberBackground shader already handles hex grid, matrix rain, circuit lines,
	# purple pulses, glowing nodes, scan lines, vignette AND the new retrowave
	# 3D perspective floor — no need to duplicate any of that here.
	# We only add the thin accent bars and corner labels for branding.

	var vp = get_viewport_rect().size

	var top = ColorRect.new()
	top.color = Color(tc["accent"]); top.position = Vector2(0, 0)
	top.size  = Vector2(vp.x, 4); top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	var top_tw = top.create_tween(); top_tw.set_loops(); top_tw.set_trans(Tween.TRANS_SINE)
	top_tw.tween_property(top, "color", Color(tc["primary"]),   2.0)
	top_tw.tween_property(top, "color", Color(tc["accent"]),    2.0)

	var bot = ColorRect.new()
	bot.color = Color(tc["primary"]); bot.position = Vector2(0, vp.y - 4)
	bot.size  = Vector2(vp.x, 4); bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bot)
	var bot_tw = bot.create_tween(); bot_tw.set_loops(); bot_tw.set_trans(Tween.TRANS_SINE)
	bot_tw.tween_property(bot, "color", Color(tc["secondary"]), 2.5)
	bot_tw.tween_property(bot, "color", Color(tc["primary"]),   2.5)

	var corner = Label.new()
	corner.text = "BUZZXZONE  |  v2.0"
	corner.add_theme_font_size_override("font_size", 11)
	corner.add_theme_color_override("font_color", Color(tc["secondary"]))
	corner.position = Vector2(vp.x - 340, vp.y - 22)
	corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(corner)

func _animate_rain_drop(drop: ColorRect):
	drop.position.y = randf_range(-100, 0)
	var tw = drop.create_tween(); tw.set_loops()
	tw.tween_property(drop, "position:y", 720.0, randf_range(1.4, 3.8))
	tw.tween_callback(func():
		drop.position.x = randf_range(0, 1152)
		drop.position.y = randf_range(-120, 0)
		drop.color.a    = randf_range(0.35, 0.9)
	)

func _animate_float(p: ColorRect):
	var tw = p.create_tween(); tw.set_loops()
	tw.set_trans(Tween.TRANS_SINE); tw.set_ease(Tween.EASE_IN_OUT)
	var ty  = p.position.y - randf_range(40, 110)
	var dur = randf_range(1.8, 5.0)
	tw.tween_property(p, "position:y", ty,  dur)
	tw.parallel().tween_property(p, "color:a", 0.08, dur)
	tw.tween_property(p, "position:y", p.position.y + randf_range(30, 100), dur)
	tw.parallel().tween_property(p, "color:a", randf_range(0.45, 0.9), dur)

# ─────────────────────────────────────────────────────────────────────────────
#  Content (left panel)
# ─────────────────────────────────────────────────────────────────────────────
func build_content():
	# Centre the panel horizontally at all viewport widths
	$VBoxContainer.anchor_left   = 0.5
	$VBoxContainer.anchor_right  = 0.5
	$VBoxContainer.anchor_top    = 0.0
	$VBoxContainer.anchor_bottom = 0.0
	$VBoxContainer.offset_left   = -290
	$VBoxContainer.offset_right  = 290
	$VBoxContainer.offset_top    = 30
	$VBoxContainer.offset_bottom = 648
	$VBoxContainer.custom_minimum_size = Vector2(580, 0)
	$VBoxContainer.add_theme_constant_override("separation", 12)

	# Badge — greets the real logged-in player instead of a fixed university badge
	var badge_bg = ColorRect.new()
	badge_bg.color = Color("#112233"); badge_bg.size = Vector2(340, 32)
	badge_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$VBoxContainer.add_child(badge_bg); $VBoxContainer.move_child(badge_bg, 0)
	var badge_lbl = Label.new()
	badge_lbl.text = "  Welcome, " + GameManager.player_name + "  "
	badge_lbl.add_theme_font_size_override("font_size", 14)
	badge_lbl.add_theme_color_override("font_color", Color("#378ADD"))
	$VBoxContainer.add_child(badge_lbl); $VBoxContainer.move_child(badge_lbl, 1)

	# Title with 3D drop-shadow and glitch effect
	_title_lbl = $VBoxContainer/Label
	_title_lbl.text = "BUZZXZONE"
	_title_lbl.add_theme_font_size_override("font_size", 68)
	_title_lbl.add_theme_color_override("font_color", Color("#FFFFFF"))
	# 3D depth shadow
	_title_lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.8, 1.0, 0.55))
	_title_lbl.add_theme_constant_override("shadow_offset_x", 4)
	_title_lbl.add_theme_constant_override("shadow_offset_y", 5)
	_title_lbl.add_theme_constant_override("shadow_outline_size", 3)

	# Tagline
	var tagline = $VBoxContainer/Label2
	tagline.text = "Race the neon streets. Build your garage."
	tagline.add_theme_font_size_override("font_size", 21)
	tagline.add_theme_color_override("font_color", Color("#85B7EB"))

	# Divider
	var div = ColorRect.new()
	div.color = Color("#1E3A5F"); div.custom_minimum_size = Vector2(400, 3)
	div.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$VBoxContainer.add_child(div); $VBoxContainer.move_child(div, 4)

	# Info line
	var info = Label.new()
	info.text = "Endless Racer  ·  Car Garage  ·  Curved Roads"
	info.add_theme_font_size_override("font_size", 15)
	info.add_theme_color_override("font_color", Color("#4A6B8A"))
	$VBoxContainer.add_child(info); $VBoxContainer.move_child(info, 5)

	var sp = Label.new(); sp.text = ""
	sp.custom_minimum_size = Vector2(0, 8)
	$VBoxContainer.add_child(sp); $VBoxContainer.move_child(sp, 6)

	# Buttons
	var start = $VBoxContainer/Button
	start.text = "  PLAY NOW  "
	start.custom_minimum_size = Vector2(320, 64)
	StyleManager.style_button(start, "#1D9E75", "#FFFFFF")

	var howto = $VBoxContainer/Button2
	howto.text = "  HOW TO PLAY  "
	howto.custom_minimum_size = Vector2(320, 56)
	StyleManager.style_button(howto, "#185FA5", "#FFFFFF")

	var quit_btn = Button.new()
	quit_btn.text = "  ✕ QUIT GAME  "
	quit_btn.custom_minimum_size = Vector2(320, 52)
	StyleManager.style_button(quit_btn, "#2A0A0A", "#CC6666")
	$VBoxContainer.add_child(quit_btn)
	quit_btn.pressed.connect(get_tree().quit)

func _animate_entrance():
	$VBoxContainer.modulate.a = 0.0
	var tw = create_tween()
	tw.set_ease(Tween.EASE_OUT); tw.set_trans(Tween.TRANS_QUAD)
	tw.tween_interval(0.15)
	tw.tween_property($VBoxContainer, "modulate:a", 1.0, 0.55)
	await get_tree().create_timer(1.1).timeout
	_pulse_button($VBoxContainer/Button)
	_start_title_glitch()

func _pulse_button(btn: Button):
	var tw = btn.create_tween(); tw.set_loops()
	tw.set_trans(Tween.TRANS_SINE); tw.set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(btn, "scale", Vector2(1.04, 1.04), 0.8)
	tw.tween_property(btn, "scale", Vector2(1.0,  1.0),  0.8)

func _start_title_glitch():
	var tw = create_tween(); tw.set_loops()
	tw.tween_interval(randf_range(3.5, 7.0))
	tw.tween_callback(_do_glitch)

func _do_glitch():
	# Glitch via colour flashes — tweening position inside VBoxContainer
	# has no visual effect because the container overrides child positions.
	if not is_instance_valid(_title_lbl): return
	var tc  = SettingsManager.get_theme_colors() if SettingsManager \
			  else {"title_a": Color("#00FFFF")}
	var gc  = tc.get("title_a", Color("#00FFFF"))
	var tw  = _title_lbl.create_tween()
	tw.tween_property(_title_lbl, "modulate", gc,                    0.04)
	tw.tween_property(_title_lbl, "modulate", Color(1, 0.15, 0.15),  0.04)
	tw.tween_property(_title_lbl, "modulate", gc,                    0.03)
	tw.tween_property(_title_lbl, "modulate", Color.WHITE,           0.04)
	tw.tween_property(_title_lbl, "modulate", Color(0.1, 1.0, 0.9),  0.03)
	tw.tween_property(_title_lbl, "modulate", Color.WHITE,           0.07)

# ─────────────────────────────────────────────────────────────────────────────
#  Settings gear button (top-right)
# ─────────────────────────────────────────────────────────────────────────────
func _add_gear_button():
	var gear = Button.new()
	gear.text = "⚙  SETTINGS"
	var vp_w = get_viewport_rect().size.x
	gear.position = Vector2(vp_w - 172, 18)
	gear.custom_minimum_size = Vector2(148, 42)
	var gs = StyleBoxFlat.new()
	gs.bg_color = Color("#112233"); gs.bg_color.a = 0.8
	gs.border_color = Color("#378ADD"); gs.set_border_width_all(2)
	gs.set_corner_radius_all(8)
	gs.content_margin_left = 12; gs.content_margin_right  = 12
	gs.content_margin_top  = 8;  gs.content_margin_bottom = 8
	gear.add_theme_stylebox_override("normal", gs)
	var gs_h: StyleBoxFlat = gs.duplicate() as StyleBoxFlat
	gs_h.bg_color = Color("#1E3A5F"); gs_h.bg_color.a = 0.9
	gear.add_theme_stylebox_override("hover", gs_h)
	gear.add_theme_color_override("font_color", Color("#85B7EB"))
	gear.add_theme_font_size_override("font_size", 15)
	gear.mouse_entered.connect(func():
		var tw = gear.create_tween()
		tw.set_trans(Tween.TRANS_BACK); tw.set_ease(Tween.EASE_OUT)
		tw.tween_property(gear, "scale", Vector2(1.06, 1.06), 0.1)
	)
	gear.mouse_exited.connect(func():
		var tw = gear.create_tween()
		tw.set_trans(Tween.TRANS_BACK); tw.set_ease(Tween.EASE_OUT)
		tw.tween_property(gear, "scale", Vector2(1.0, 1.0), 0.1)
	)
	gear.pressed.connect(_on_settings_pressed)
	add_child(gear)

# ─────────────────────────────────────────────────────────────────────────────
#  Button handlers
# ─────────────────────────────────────────────────────────────────────────────
func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()

func _on_start_pressed():
	await get_tree().create_timer(0.28).timeout
	GameManager.reset_game()
	_fade_out_then("res://scenes/garage.tscn")

func _on_howto_pressed():
	_show_howto_popup()

func _on_settings_pressed():
	if SettingsManager:
		SettingsManager.open_settings_popup(self)

func _show_howto_popup():
	var popup_bg = ColorRect.new()
	popup_bg.color = Color(0, 0, 0, 0.0)
	popup_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup_bg.z_index = 50; add_child(popup_bg)

	var panel = PanelContainer.new()
	panel.position = Vector2(200, 75); panel.custom_minimum_size = Vector2(750, 490)
	panel.z_index  = 51; panel.scale = Vector2(0.5, 0.5); panel.modulate.a = 0.0
	add_child(panel)

	var style = StyleBoxFlat.new()
	style.bg_color = Color("#0A1628"); style.border_color = Color("#185FA5")
	style.set_border_width_all(3); style.set_corner_radius_all(16)
	style.content_margin_left = 30; style.content_margin_right  = 30
	style.content_margin_top  = 24; style.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14); panel.add_child(vbox)

	var title = Label.new()
	title.text = "HOW TO PLAY"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("#378ADD"))
	vbox.add_child(title)

	var steps = [
		["Garage",   "Pick, buy and customise your car before racing", "#E24B4A"],
		["Controls", "W/A/S/D or Arrow Keys to drive — on-screen buttons on mobile", "#EF9F27"],
		["Curves",   "The road winds — steer to stay on it as it bends", "#9B59B6"],
		["Coins",    "Collect gold coins to unlock new cars in the Garage", "#1D9E75"],
		["Survive",  "Dodge traffic — you've got 3 lives per run", "#FF4444"],
	]
	for step in steps:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		vbox.add_child(row)
		var dot = ColorRect.new()
		dot.color = Color(step[2]); dot.custom_minimum_size = Vector2(8, 40)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(dot)
		var lbl = Label.new()
		lbl.text = step[0] + " — " + step[1]
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.add_theme_color_override("font_color", Color("#85B7EB"))
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.custom_minimum_size = Vector2(600, 0)
		row.add_child(lbl)

	var tip = Label.new()
	tip.text = "Tip: the longer you survive, the faster and denser traffic gets!"
	tip.add_theme_font_size_override("font_size", 14)
	tip.add_theme_color_override("font_color", Color("#1D9E75"))
	vbox.add_child(tip)

	var close_btn = Button.new()
	close_btn.text = "  GOT IT — LET'S PLAY!  "
	close_btn.custom_minimum_size = Vector2(300, 52)
	StyleManager.style_button(close_btn, "#1D9E75", "#FFFFFF")
	vbox.add_child(close_btn)

	var tw = create_tween(); tw.set_ease(Tween.EASE_OUT); tw.set_trans(Tween.TRANS_BACK)
	tw.tween_property(popup_bg, "color:a", 0.72, 0.2)
	tw.parallel().tween_property(panel, "scale",      Vector2(1.0, 1.0), 0.3)
	tw.parallel().tween_property(panel, "modulate:a", 1.0,               0.3)

	close_btn.pressed.connect(func():
		var tw2 = create_tween(); tw2.set_ease(Tween.EASE_IN)
		tw2.tween_property(panel,    "scale",      Vector2(0.5, 0.5), 0.2)
		tw2.parallel().tween_property(panel,    "modulate:a", 0.0,           0.2)
		tw2.parallel().tween_property(popup_bg, "color:a",    0.0,           0.2)
		tw2.tween_callback(func(): panel.queue_free(); popup_bg.queue_free())
	)
