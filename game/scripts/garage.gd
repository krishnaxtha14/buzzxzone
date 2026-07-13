extends Control

var _overlay: ColorRect

func _ready():
	_create_overlay()
	StyleManager.style_scene(self, "#185FA5")
	_build_header()
	_build_car_grid()
	_build_footer()
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

# -----------------------------------------------------------------------------
#  Header
# -----------------------------------------------------------------------------
func _build_header():
	var title = Label.new()
	title.text = "GARAGE"
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color("#FFFFFF"))
	title.position = Vector2(60, 30)
	add_child(title)

	var sub = Label.new()
	sub.text = "Pick your car, then hit the road."
	sub.add_theme_font_size_override("font_size", 15)
	sub.add_theme_color_override("font_color", Color("#4A6B8A"))
	sub.position = Vector2(62, 88)
	add_child(sub)

	var total = SettingsManager.race_coins if SettingsManager else 0
	var coin_lbl = Label.new()
	coin_lbl.text = "Coins: " + str(total)
	coin_lbl.add_theme_font_size_override("font_size", 20)
	coin_lbl.add_theme_color_override("font_color", Color("#EEB800"))
	var vp = get_viewport_rect().size
	coin_lbl.position = Vector2(vp.x - 220, 34)
	add_child(coin_lbl)

# -----------------------------------------------------------------------------
#  Car grid
# -----------------------------------------------------------------------------
func _build_car_grid():
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.position = Vector2(60, 160)
	add_child(row)

	var total  = SettingsManager.race_coins    if SettingsManager else 0
	var owned  = SettingsManager.race_owned    if SettingsManager else ["blue"]
	var sel    = SettingsManager.race_selected if SettingsManager else "blue"

	for car in SettingsManager.CAR_DEFS:
		var card = VBoxContainer.new(); card.add_theme_constant_override("separation", 8)
		card.custom_minimum_size = Vector2(190, 0)
		var cst = StyleBoxFlat.new()
		cst.bg_color = Color(0.04,0.12,0.04) if car.id == sel else Color(0.06,0.06,0.16)
		cst.border_color = car.accent; cst.set_border_width_all(2 if car.id != sel else 3)
		cst.set_corner_radius_all(12)
		cst.shadow_color = Color(0,0,0,0.5); cst.shadow_size = 6; cst.shadow_offset = Vector2(3,4)
		cst.content_margin_left = 12; cst.content_margin_right = 12
		cst.content_margin_top = 12; cst.content_margin_bottom = 12
		var cp = PanelContainer.new(); cp.add_theme_stylebox_override("panel", cst)
		var ci = VBoxContainer.new(); ci.add_theme_constant_override("separation", 8)
		cp.add_child(ci); row.add_child(cp)

		var sw = ColorRect.new()
		sw.color = car.body; sw.custom_minimum_size = Vector2(166, 56)
		sw.mouse_filter = Control.MOUSE_FILTER_IGNORE; ci.add_child(sw)
		var ac = ColorRect.new()
		ac.color = car.accent; ac.custom_minimum_size = Vector2(166, 8)
		ac.mouse_filter = Control.MOUSE_FILTER_IGNORE; ci.add_child(ac)

		var nl = Label.new(); nl.text = car.label
		nl.add_theme_font_size_override("font_size", 15)
		nl.add_theme_color_override("font_color", car.accent)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; ci.add_child(nl)

		var is_owned = car.id in owned; var is_sel = car.id == sel
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(162, 40); btn.add_theme_font_size_override("font_size", 14)
		if is_sel:
			btn.text = "OK SELECTED"; StyleManager.style_button(btn, "#1D5A35", "#22EE66")
		elif is_owned:
			btn.text = "SELECT"; StyleManager.style_button(btn, "#185FA5", "#FFFFFF")
		else:
			btn.text = "BUY " + str(car.price)
			StyleManager.style_button(btn, "#3A1A50" if total >= car.price else "#111118", "#FFFFFF")
			btn.disabled = total < car.price
		ci.add_child(btn)

		var cid = car.id; var cp2 = car.price
		btn.pressed.connect(func():
			if not (cid in (SettingsManager.race_owned if SettingsManager else ["blue"])):
				if SettingsManager: SettingsManager.race_coins -= cp2; SettingsManager.race_owned.append(cid)
			if SettingsManager: SettingsManager.race_selected = cid; SettingsManager.save_settings()
			get_tree().reload_current_scene()
		)

# -----------------------------------------------------------------------------
#  Footer — Race + Menu buttons
# -----------------------------------------------------------------------------
func _build_footer():
	var vp = get_viewport_rect().size

	var race_btn = Button.new()
	race_btn.text = "  RACE >>>  "
	race_btn.custom_minimum_size = Vector2(260, 60)
	StyleManager.style_button(race_btn, "#1D9E75", "#FFFFFF")
	race_btn.position = Vector2(vp.x - 300, vp.y - 90)
	add_child(race_btn)
	race_btn.pressed.connect(func(): _fade_out_then("res://scenes/race_3d.tscn"))

	var menu_btn = Button.new()
	menu_btn.text = "  <-- MENU  "
	menu_btn.custom_minimum_size = Vector2(180, 52)
	StyleManager.style_button(menu_btn, "#185FA5", "#FFFFFF")
	menu_btn.position = Vector2(60, vp.y - 86)
	add_child(menu_btn)
	menu_btn.pressed.connect(func(): _fade_out_then("res://scenes/main_menu.tscn"))
