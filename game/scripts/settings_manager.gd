extends Node

const SAVE_PATH = "user://cyber_guardian.cfg"

var music_volume: float = 0.5
var sfx_volume:   float = 0.85
var bg_theme:     String = "matrix"   # matrix | neon | hex | space | synthwave
var difficulty:   String = "normal"   # easy | normal | hard
var cursor_trail: bool   = true

# Racing game persistence
var race_coins:    int    = 0
var race_owned:    Array  = ["blue"]
var race_selected: String = "blue"

signal settings_changed

func _ready():
	load_settings()

func save_settings():
	var cfg = ConfigFile.new()
	cfg.set_value("audio",    "music",      music_volume)
	cfg.set_value("audio",    "sfx",        sfx_volume)
	cfg.set_value("visuals",  "theme",      bg_theme)
	cfg.set_value("visuals",  "trail",      cursor_trail)
	cfg.set_value("gameplay", "difficulty", difficulty)
	cfg.set_value("race",     "coins",      race_coins)
	cfg.set_value("race",     "owned",      race_owned)
	cfg.set_value("race",     "selected",   race_selected)
	cfg.save(SAVE_PATH)
	settings_changed.emit()

func load_settings():
	var cfg = ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	music_volume   = cfg.get_value("audio",    "music",      0.5)
	sfx_volume     = cfg.get_value("audio",    "sfx",        0.85)
	bg_theme       = cfg.get_value("visuals",  "theme",      "matrix")
	cursor_trail   = cfg.get_value("visuals",  "trail",      true)
	difficulty     = cfg.get_value("gameplay", "difficulty", "normal")
	race_coins     = cfg.get_value("race",     "coins",      0)
	race_owned     = cfg.get_value("race",     "owned",      ["blue"])
	race_selected  = cfg.get_value("race",     "selected",   "blue")

func get_lives() -> int:
	match difficulty:
		"easy":  return 5
		"hard":  return 2
	return 3

func get_boss_time() -> int:
	match difficulty:
		"easy":  return 120
		"hard":  return 60
	return 90

func get_theme_colors() -> Dictionary:
	match bg_theme:
		"neon":
			return {bg="#0D001A", primary="#FF00FF", secondary="#00FFFF",
					accent="#FF69B4", grid="#8B008B", rain="#FF00AA",
					title_a=Color("#FF00FF"), title_b=Color("#00FFFF")}
		"space":
			return {bg="#000510", primary="#4488FF", secondary="#AADDFF",
					accent="#00BFFF", grid="#1A2A4A", rain="#8888FF",
					title_a=Color("#4488FF"), title_b=Color("#FFFFFF")}
		"synthwave":
			return {bg="#0A0015", primary="#FF6B35", secondary="#F7C59F",
					accent="#9B59B6", grid="#3D0066", rain="#FF3366",
					title_a=Color("#FF6B35"), title_b=Color("#9B59B6")}
		"hex":
			return {bg="#001A0D", primary="#00FF88", secondary="#00CCFF",
					accent="#88FF00", grid="#003322", rain="#00FF66",
					title_a=Color("#00FF88"), title_b=Color("#00CCFF")}
		"minimal":
			return {bg="#0A0A0F", primary="#AAAACC", secondary="#888899",
					accent="#FFFFFF", grid="#1A1A2A", rain="#AAAACC",
					title_a=Color("#AAAACC"), title_b=Color("#FFFFFF")}
		_:  # matrix
			return {bg="#050D1A", primary="#00FF66", secondary="#185FA5",
					accent="#00FFFF", grid="#0A2A0A", rain="#00FF66",
					title_a=Color("#00FFFF"), title_b=Color("#1D9E75")}

func open_settings_popup(parent: Node):
	_build_settings_ui(parent)

# ──────────────────────────────────────────
#  Settings popup (spawned on any scene)
# ──────────────────────────────────────────
func _build_settings_ui(parent: Node):
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.z_index = 80
	parent.add_child(dim)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 530)
	panel.z_index = 81
	panel.scale = Vector2(0.5, 0.5)
	panel.modulate.a = 0.0
	parent.add_child(panel)

	var st = StyleBoxFlat.new()
	st.bg_color      = Color("#08101E")
	st.border_color  = Color("#185FA5")
	st.set_border_width_all(3)
	st.set_corner_radius_all(16)
	st.content_margin_left   = 28
	st.content_margin_right  = 28
	st.content_margin_top    = 22
	st.content_margin_bottom = 22
	# 3D panel shadow
	st.shadow_color  = Color(0, 0, 0, 0.75)
	st.shadow_size   = 12
	st.shadow_offset = Vector2(6, 8)
	panel.add_theme_stylebox_override("panel", st)

	# Center the panel
	var vp_size = Vector2(1152, 648)
	panel.position = (vp_size - panel.custom_minimum_size) / 2.0

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "SETTINGS"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("#00FFFF"))
	vbox.add_child(title)

	_sep(vbox)

	# ── AUDIO ───────────────────────────────
	_section_label(vbox, "  AUDIO")

	var music_row = HBoxContainer.new()
	music_row.add_theme_constant_override("separation", 12)
	vbox.add_child(music_row)
	var ml = Label.new(); ml.text = "Music Volume"
	ml.add_theme_font_size_override("font_size", 16)
	ml.add_theme_color_override("font_color", Color("#85B7EB"))
	ml.custom_minimum_size = Vector2(180, 0)
	music_row.add_child(ml)
	var music_slider = HSlider.new()
	music_slider.min_value = 0.0; music_slider.max_value = 1.0
	music_slider.step = 0.05; music_slider.value = music_volume
	music_slider.custom_minimum_size = Vector2(320, 28)
	music_row.add_child(music_slider)
	var mv_lbl = Label.new()
	mv_lbl.text = str(int(music_volume * 100)) + "%"
	mv_lbl.add_theme_font_size_override("font_size", 15)
	mv_lbl.add_theme_color_override("font_color", Color("#FFFFFF"))
	mv_lbl.custom_minimum_size = Vector2(50, 0)
	music_row.add_child(mv_lbl)

	var sfx_row = HBoxContainer.new()
	sfx_row.add_theme_constant_override("separation", 12)
	vbox.add_child(sfx_row)
	var sl = Label.new(); sl.text = "SFX Volume"
	sl.add_theme_font_size_override("font_size", 16)
	sl.add_theme_color_override("font_color", Color("#85B7EB"))
	sl.custom_minimum_size = Vector2(180, 0)
	sfx_row.add_child(sl)
	var sfx_slider = HSlider.new()
	sfx_slider.min_value = 0.0; sfx_slider.max_value = 1.0
	sfx_slider.step = 0.05; sfx_slider.value = sfx_volume
	sfx_slider.custom_minimum_size = Vector2(320, 28)
	sfx_row.add_child(sfx_slider)
	var sv_lbl = Label.new()
	sv_lbl.text = str(int(sfx_volume * 100)) + "%"
	sv_lbl.add_theme_font_size_override("font_size", 15)
	sv_lbl.add_theme_color_override("font_color", Color("#FFFFFF"))
	sv_lbl.custom_minimum_size = Vector2(50, 0)
	sfx_row.add_child(sv_lbl)

	music_slider.value_changed.connect(func(v):
		mv_lbl.text = str(int(v * 100)) + "%"
		music_volume = v
		if get_node_or_null("/root/AudioManager"):
			get_node("/root/AudioManager").set_music_volume(v)
	)
	sfx_slider.value_changed.connect(func(v):
		sv_lbl.text = str(int(v * 100)) + "%"
		sfx_volume = v
		if get_node_or_null("/root/AudioManager"):
			get_node("/root/AudioManager").set_sfx_volume(v)
	)

	_sep(vbox)

	# ── BACKGROUND THEME ────────────────────
	_section_label(vbox, "  BACKGROUND THEME")

	var theme_row = HBoxContainer.new()
	theme_row.add_theme_constant_override("separation", 8)
	vbox.add_child(theme_row)
	var themes  = ["matrix", "neon", "hex", "space", "synthwave"]
	var t_names = ["MATRIX", "NEON", "HEX", "SPACE", "SYNTH"]
	var t_colors= ["#00FF66", "#FF00FF", "#00FF88", "#4488FF", "#FF6B35"]
	for i in range(themes.size()):
		var tb = Button.new()
		tb.text = t_names[i]
		tb.custom_minimum_size = Vector2(120, 40)
		var sn = StyleBoxFlat.new()
		sn.bg_color = Color(t_colors[i])
		sn.bg_color.a = 0.2 if themes[i] != bg_theme else 0.6
		sn.border_color = Color(t_colors[i])
		sn.set_border_width_all(2 if themes[i] != bg_theme else 3)
		sn.set_corner_radius_all(8)
		sn.content_margin_left = 8; sn.content_margin_right = 8
		sn.content_margin_top = 8;  sn.content_margin_bottom = 8
		tb.add_theme_stylebox_override("normal", sn)
		tb.add_theme_color_override("font_color", Color(t_colors[i]))
		tb.add_theme_font_size_override("font_size", 14)
		theme_row.add_child(tb)
		var tname = themes[i]
		tb.pressed.connect(func():
			bg_theme = tname
			_refresh_theme_buttons(theme_row, themes, t_colors)
		)

	_sep(vbox)

	# ── DIFFICULTY ──────────────────────────
	_section_label(vbox, "  DIFFICULTY")

	var diff_row = HBoxContainer.new()
	diff_row.add_theme_constant_override("separation", 12)
	vbox.add_child(diff_row)
	var diffs  = ["easy", "normal", "hard"]
	var d_names= ["EASY (5 lives)", "NORMAL (3 lives)", "HARD (2 lives)"]
	var d_cols = ["#1D9E75", "#378ADD", "#E24B4A"]
	for i in range(diffs.size()):
		var db = Button.new()
		db.text = d_names[i]
		db.custom_minimum_size = Vector2(175, 42)
		var ds = StyleBoxFlat.new()
		ds.bg_color = Color(d_cols[i])
		ds.bg_color.a = 0.15 if diffs[i] != difficulty else 0.55
		ds.border_color = Color(d_cols[i])
		ds.set_border_width_all(2 if diffs[i] != difficulty else 3)
		ds.set_corner_radius_all(8)
		ds.content_margin_left = 10; ds.content_margin_right = 10
		ds.content_margin_top = 8;   ds.content_margin_bottom = 8
		db.add_theme_stylebox_override("normal", ds)
		db.add_theme_color_override("font_color", Color(d_cols[i]))
		db.add_theme_font_size_override("font_size", 14)
		diff_row.add_child(db)
		var dname = diffs[i]
		db.pressed.connect(func():
			difficulty = dname
			_refresh_diff_buttons(diff_row, diffs, d_cols)
		)

	_sep(vbox)

	# ── CURSOR TRAIL ────────────────────────
	var trail_row = HBoxContainer.new()
	trail_row.add_theme_constant_override("separation", 16)
	vbox.add_child(trail_row)
	var tl = Label.new(); tl.text = "Cursor Trail Effect"
	tl.add_theme_font_size_override("font_size", 16)
	tl.add_theme_color_override("font_color", Color("#85B7EB"))
	trail_row.add_child(tl)
	var trail_btn = Button.new()
	trail_btn.text = "ON" if cursor_trail else "OFF"
	trail_btn.custom_minimum_size = Vector2(90, 36)
	var ts_col = "#1D9E75" if cursor_trail else "#E24B4A"
	var trail_style = StyleBoxFlat.new()
	trail_style.bg_color = Color(ts_col); trail_style.bg_color.a = 0.4
	trail_style.border_color = Color(ts_col)
	trail_style.set_border_width_all(2)
	trail_style.set_corner_radius_all(8)
	trail_style.content_margin_left = 10; trail_style.content_margin_right = 10
	trail_style.content_margin_top = 6;   trail_style.content_margin_bottom = 6
	trail_btn.add_theme_stylebox_override("normal", trail_style)
	trail_btn.add_theme_color_override("font_color", Color(ts_col))
	trail_btn.add_theme_font_size_override("font_size", 15)
	trail_row.add_child(trail_btn)
	trail_btn.pressed.connect(func():
		cursor_trail = not cursor_trail
		trail_btn.text = "ON" if cursor_trail else "OFF"
		var nc = "#1D9E75" if cursor_trail else "#E24B4A"
		trail_style.bg_color = Color(nc); trail_style.bg_color.a = 0.4
		trail_style.border_color = Color(nc)
		trail_btn.add_theme_color_override("font_color", Color(nc))
		if get_node_or_null("/root/CursorManager"):
			get_node("/root/CursorManager").set_trail_enabled(cursor_trail)
	)

	# ── SAVE BUTTON ─────────────────────────
	var save_btn = Button.new()
	save_btn.text = "  SAVE & CLOSE  "
	save_btn.custom_minimum_size = Vector2(260, 52)
	var ss = StyleBoxFlat.new()
	ss.bg_color = Color("#1D9E75"); ss.bg_color.a = 0.85
	ss.set_corner_radius_all(10)
	ss.content_margin_left = 20; ss.content_margin_right = 20
	ss.content_margin_top = 14;  ss.content_margin_bottom = 14
	save_btn.add_theme_stylebox_override("normal", ss)
	save_btn.add_theme_color_override("font_color", Color("#FFFFFF"))
	save_btn.add_theme_font_size_override("font_size", 18)
	vbox.add_child(save_btn)

	# Animate in
	var tw = parent.create_tween()
	tw.set_ease(Tween.EASE_OUT)
	tw.set_trans(Tween.TRANS_BACK)
	tw.tween_property(dim,   "color:a",    0.72, 0.22)
	tw.parallel().tween_property(panel, "scale",      Vector2(1, 1), 0.3)
	tw.parallel().tween_property(panel, "modulate:a", 1.0,           0.3)

	save_btn.pressed.connect(func():
		save_settings()
		var tw2 = parent.create_tween()
		tw2.set_ease(Tween.EASE_IN)
		tw2.tween_property(panel, "scale",      Vector2(0.5, 0.5), 0.2)
		tw2.parallel().tween_property(panel, "modulate:a", 0.0, 0.2)
		tw2.parallel().tween_property(dim,   "color:a",    0.0, 0.2)
		tw2.tween_callback(func():
			panel.queue_free()
			dim.queue_free()
		)
	)

static func _section_label(vbox: VBoxContainer, txt: String):
	var lbl = Label.new()
	lbl.text = txt
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color("#378ADD"))
	vbox.add_child(lbl)

static func _sep(vbox: VBoxContainer):
	var line = ColorRect.new()
	line.color = Color("#1E3A5F")
	line.custom_minimum_size = Vector2(0, 2)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(line)

static func _refresh_theme_buttons(row: HBoxContainer, themes: Array, cols: Array):
	var sm = row.get_node_or_null("/root/SettingsManager")
	if not sm: return
	var cur = sm.bg_theme
	for i in range(row.get_child_count()):
		var btn: Button = row.get_child(i)
		var st: StyleBoxFlat = btn.get_theme_stylebox("normal")
		if not st: continue
		var active = (themes[i] == cur)
		st.bg_color.a      = 0.6 if active else 0.2
		st.border_width_bottom = 3 if active else 2
		st.border_width_left   = 3 if active else 2
		st.border_width_right  = 3 if active else 2
		st.border_width_top    = 3 if active else 2

static func _refresh_diff_buttons(row: HBoxContainer, diffs: Array, cols: Array):
	var sm = row.get_node_or_null("/root/SettingsManager")
	if not sm: return
	var cur = sm.difficulty
	for i in range(row.get_child_count()):
		var btn: Button = row.get_child(i)
		var st: StyleBoxFlat = btn.get_theme_stylebox("normal")
		if not st: continue
		var active = (diffs[i] == cur)
		st.bg_color.a          = 0.55 if active else 0.15
		st.border_width_bottom = 3 if active else 2
		st.border_width_left   = 3 if active else 2
		st.border_width_right  = 3 if active else 2
		st.border_width_top    = 3 if active else 2
