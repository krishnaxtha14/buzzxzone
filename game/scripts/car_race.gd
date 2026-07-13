extends Control

# ── State ─────────────────────────────────────────────────────────────────────
enum GS { TUTORIAL, PLAYING, QUESTION, CRASH_Q, SHOP, GAME_OVER }

# ── Layout ────────────────────────────────────────────────────────────────────
const VW        = 1152.0
const VH        = 648.0
const ROAD_L    = 196.0
const ROAD_R    = 956.0
const HUD_H     = 64.0
const LANE_CX   = [291.0, 481.0, 671.0, 861.0]
const CAR_W     = 64.0
const CAR_H     = 104.0
const COIN_R    = 14.0
const MARK_H    = 34.0
const MARK_GAP  = 22.0
const MARK_PER  = MARK_H + MARK_GAP
const DESPAWN_Y = VH + 30.0
const Q_IVTIME  = 20.0
const SPD_DEF   = 220.0
const SPD_MIN   = 80.0
const SPD_MAX   = 480.0
const SPD_ACC   = 90.0

const QUESTIONS = [
	{q="What is phishing?",
	 opts=["A fishing sport","Fake messages used to steal personal data","A type of virus","A password method"],
	 correct=1, hint="'Phish' = fake hook. Attackers bait you with convincing fake emails!"},
	{q="Which password is STRONGEST?",
	 opts=["password123","MyDog2020!","Xk#9mB!2vPq@z","abcdefgh"],
	 correct=2, hint="Strong = LONG + UPPER + lower + numbers + symbols, no dictionary words"},
	{q="What does HTTPS mean?",
	 opts=["Faster page load","Encrypted secure connection","Government owned site","High Traffic Protocol"],
	 correct=1, hint="The padlock in your browser = HTTPS = your data is encrypted"},
	{q="What is smishing?",
	 opts=["Social media phishing","Phishing via SMS/text","Phishing via email","A phone virus"],
	 correct=1, hint="SMS + phishing = smishing. 'You won a prize!' texts are classic!"},
	{q="Best practice on public WiFi?",
	 opts=["Log into online banking","Use a VPN","Auto-connect everywhere","Share your password"],
	 correct=1, hint="VPN = encrypted tunnel protecting your data even on public WiFi"},
	{q="What is two-factor authentication (2FA)?",
	 opts=["Two passwords in a row","Extra verification step beyond password","Two email accounts","A firewall type"],
	 correct=1, hint="2FA = something you KNOW (password) + something you HAVE (phone code)"},
	{q="What is ransomware?",
	 opts=["PC speedup tool","Malware that encrypts files and demands payment","Antivirus program","Password manager"],
	 correct=1, hint="RANSOM = payment demand. It locks your files and holds them hostage!"},
	{q="Unknown USB drive found on the floor — what do you do?",
	 opts=["Plug in to check","Never plug in unknown drives","Scan it first","Give to a friend"],
	 correct=1, hint="BadUSB can load malware the MOMENT you plug in. Don't do it!"},
	{q="What is a data breach?",
	 opts=["Slow internet","Unauthorised access exposing private data","A computer crash","Update failure"],
	 correct=1, hint="BREACH = hole in defences. Private data escapes to attackers!"},
	{q="Which is NOT a phishing red flag?",
	 opts=["Urgent 'act now' language","Email from verified friend with no attachment","Misspelled domain","Asks for your password"],
	 correct=1, hint="Emails from verified trusted contacts with no suspicious link are NOT red flags"},
]

const CAR_DEFS = [
	{id="blue",   label="Stealth Runner",  price=0,   col=Color("#1C3050"), acc=Color("#3A6080")},
	{id="green",  label="Forest Racer",    price=50,  col=Color("#183828"), acc=Color("#2E6038")},
	{id="red",    label="Danger Speed",    price=100, col=Color("#6A1818"), acc=Color("#9A2828")},
	{id="purple", label="Ghost Phantom",   price=200, col=Color("#2E1848"), acc=Color("#5A3878")},
	{id="gold",   label="Elite Guardian",  price=500, col=Color("#604E10"), acc=Color("#A08020")},
]

var _gs:            int   = GS.TUTORIAL
var _lives:         int   = 3
var _score:         int   = 0
var _coins:         int   = 0
var _speed:         float = SPD_DEF
var _qtimer:        float = Q_IVTIME
var _scroll:        float = 0.0
var _q_idx:         int   = 0
var _q_order:       Array = []
var _crash_pending: bool  = false

var _player:     Control
var _player_x:   float  = LANE_CX[1]
var _enemies:    Array  = []
var _coin_nodes: Array  = []
var _road_marks: Array  = []

var _spawn_t:  float = 0.0
var _spawn_iv: float = 2.4
var _ctimer:   float = 0.0
var _coin_iv:  float = 3.0

var _hud_lives: Label
var _hud_score: Label
var _hud_coins: Label
var _hud_speed: Label
var _hud_qtmr:  Label
var _game_layer: Control

func _ready():
	_coins   = SettingsManager.race_coins if SettingsManager else 0
	_lives   = SettingsManager.get_lives() if SettingsManager else 3
	_q_order = range(QUESTIONS.size())
	_q_order.shuffle()
	_build_scene()
	_show_tutorial()

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()

func _process(delta: float):
	if _gs != GS.PLAYING:
		return
	_handle_input(delta)
	_scroll_marks(delta)
	_move_enemies(delta)
	_spawn_logic(delta)
	_check_collisions()
	_score += int(delta * _speed * 0.07)
	_qtimer -= delta
	if _qtimer <= 0.0:
		_qtimer = Q_IVTIME
		_show_question(false)
	_refresh_hud()

func _handle_input(delta: float):
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		_player_x -= 310.0 * delta
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		_player_x += 310.0 * delta
	_player_x = clampf(_player_x,
		ROAD_L + CAR_W * 0.5 + 6,
		ROAD_R - CAR_W * 0.5 - 6)
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		_speed = minf(_speed + SPD_ACC * delta, SPD_MAX)
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		_speed = maxf(_speed - SPD_ACC * delta, SPD_MIN)
	_player.position.x = _player_x - CAR_W * 0.5

func _build_scene():
	var bg = ColorRect.new()
	bg.color = Color("#0A0C14")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	for gx in [Vector2(0, ROAD_L), Vector2(ROAD_R, VW - ROAD_R)]:
		var grass = ColorRect.new()
		grass.color = Color("#0C140C")
		grass.position = Vector2(gx.x, HUD_H)
		grass.size = Vector2(gx.y, VH - HUD_H)
		grass.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(grass)

	var road = ColorRect.new()
	road.color = Color("#1A1C2A")
	road.position = Vector2(ROAD_L, HUD_H)
	road.size = Vector2(ROAD_R - ROAD_L, VH - HUD_H)
	road.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(road)

	for ex in [ROAD_L, ROAD_R - 10]:
		var sh = ColorRect.new()
		sh.color = Color("#20223A")
		sh.position = Vector2(ex, HUD_H)
		sh.size = Vector2(10, VH - HUD_H)
		sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(sh)

	for ex in [ROAD_L + 9, ROAD_R - 12]:
		var edge = ColorRect.new()
		edge.color = Color(0.70, 0.75, 0.85, 0.55)
		edge.position = Vector2(ex, HUD_H)
		edge.size = Vector2(3, VH - HUD_H)
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(edge)

	var pgrid = ColorRect.new()
	pgrid.position = Vector2(ROAD_L, HUD_H)
	pgrid.size = Vector2(ROAD_R - ROAD_L, VH - HUD_H)
	pgrid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh2 = Shader.new()
	sh2.code = """
shader_type canvas_item;
void fragment() {
	vec2 uv = UV;
	float horizon = 0.05;
	if (uv.y < horizon) { COLOR = vec4(0.0); return; }
	float d = (uv.y - horizon) / (1.0 - horizon);
	float dd = d * d;
	float px = (uv.x - 0.5) / max(dd, 0.002) * 0.20;
	float pz = 1.0 / max(dd, 0.002) * 0.05 + TIME * 0.38;
	float gx = abs(fract(px) - 0.5);
	float gz = abs(fract(pz) - 0.5);
	float lx = smoothstep(0.47, 0.41, gx) * smoothstep(1.0, 0.5, abs(uv.x - 0.5) * 2.0);
	float lz = smoothstep(0.47, 0.41, gz);
	float fade = smoothstep(0.0, 0.08, d) * smoothstep(1.0, 0.72, uv.y);
	float g = max(lx, lz) * fade * 0.38;
	COLOR = vec4(vec3(0.20, 0.28, 0.46) * g, g * 0.28);
}
"""
	var mat = ShaderMaterial.new()
	mat.shader = sh2
	pgrid.material = mat
	add_child(pgrid)

	_game_layer = Control.new()
	_game_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_game_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_game_layer)

	_build_road_marks()
	_spawn_player()
	_build_hud()
	StyleManager.add_back_button(self, "res://scenes/mission_select.tscn")
	_add_quit_button()
	_build_touch_controls()

func _add_quit_button():
	var btn = Button.new()
	btn.text = "✕ Quit"
	btn.z_index = 90
	btn.position = Vector2(VW - 110, 12)
	btn.custom_minimum_size = Vector2(96, 42)
	var sn = StyleBoxFlat.new()
	sn.bg_color = Color("#1C0808")
	sn.bg_color.a = 0.92
	sn.border_color = Color("#5A2020")
	sn.set_border_width_all(2)
	sn.set_corner_radius_all(8)
	sn.content_margin_left = 10
	sn.content_margin_right = 10
	sn.content_margin_top = 6
	sn.content_margin_bottom = 6
	btn.add_theme_stylebox_override("normal", sn)
	var sh = sn.duplicate() as StyleBoxFlat
	sh.bg_color = Color("#3A1010")
	sh.bg_color.a = 0.96
	sh.border_color = Color("#884040")
	btn.add_theme_stylebox_override("hover", sh)
	btn.add_theme_color_override("font_color", Color("#BB5050"))
	btn.add_theme_font_size_override("font_size", 14)
	btn.mouse_entered.connect(func():
		var tw = btn.create_tween()
		tw.set_trans(Tween.TRANS_BACK)
		tw.set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2(1.06, 1.06), 0.09)
	)
	btn.mouse_exited.connect(func():
		var tw = btn.create_tween()
		tw.set_trans(Tween.TRANS_BACK)
		tw.set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.09)
	)
	add_child(btn)
	btn.pressed.connect(get_tree().quit)

func _build_touch_controls():
	var touch_layer = CanvasLayer.new()
	touch_layer.layer = 10
	add_child(touch_layer)
	var container = Control.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	touch_layer.add_child(container)
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(1, 1, 1, 0.15)
	btn_style.border_color = Color(1, 1, 1, 0.4)
	btn_style.set_border_width_all(2)
	btn_style.set_corner_radius_all(12)
	var btn_pressed = StyleBoxFlat.new()
	btn_pressed.bg_color = Color(1, 1, 1, 0.35)
	btn_pressed.border_color = Color(1, 1, 1, 0.8)
	btn_pressed.set_border_width_all(2)
	btn_pressed.set_corner_radius_all(12)
	var left_btn = Button.new()
	left_btn.text = "◀"
	left_btn.position = Vector2(20, VH - 160)
	left_btn.custom_minimum_size = Vector2(100, 100)
	left_btn.add_theme_stylebox_override("normal", btn_style)
	left_btn.add_theme_stylebox_override("pressed", btn_pressed)
	left_btn.add_theme_font_size_override("font_size", 36)
	left_btn.add_theme_color_override("font_color", Color("#FFFFFF"))
	container.add_child(left_btn)
	var right_btn = Button.new()
	right_btn.text = "▶"
	right_btn.position = Vector2(140, VH - 160)
	right_btn.custom_minimum_size = Vector2(100, 100)
	right_btn.add_theme_stylebox_override("normal", btn_style)
	right_btn.add_theme_stylebox_override("pressed", btn_pressed)
	right_btn.add_theme_font_size_override("font_size", 36)
	right_btn.add_theme_color_override("font_color", Color("#FFFFFF"))
	container.add_child(right_btn)
	var up_btn = Button.new()
	up_btn.text = "▲"
	up_btn.position = Vector2(VW - 130, VH - 220)
	up_btn.custom_minimum_size = Vector2(100, 100)
	up_btn.add_theme_stylebox_override("normal", btn_style)
	up_btn.add_theme_stylebox_override("pressed", btn_pressed)
	up_btn.add_theme_font_size_override("font_size", 36)
	up_btn.add_theme_color_override("font_color", Color("#00FF88"))
	container.add_child(up_btn)
	var down_btn = Button.new()
	down_btn.text = "▼"
	down_btn.position = Vector2(VW - 130, VH - 110)
	down_btn.custom_minimum_size = Vector2(100, 100)
	down_btn.add_theme_stylebox_override("normal", btn_style)
	down_btn.add_theme_stylebox_override("pressed", btn_pressed)
	down_btn.add_theme_font_size_override("font_size", 36)
	down_btn.add_theme_color_override("font_color", Color("#FF4444"))
	container.add_child(down_btn)
	left_btn.button_down.connect(func(): Input.action_press("ui_left"))
	left_btn.button_up.connect(func(): Input.action_release("ui_left"))
	right_btn.button_down.connect(func(): Input.action_press("ui_right"))
	right_btn.button_up.connect(func(): Input.action_release("ui_right"))
	up_btn.button_down.connect(func(): Input.action_press("ui_up"))
	up_btn.button_up.connect(func(): Input.action_release("ui_up"))
	down_btn.button_down.connect(func(): Input.action_press("ui_down"))
	down_btn.button_up.connect(func(): Input.action_release("ui_down"))

func _build_road_marks():
	var n = int((VH - HUD_H) / MARK_PER) + 3
	var lane_w = (ROAD_R - ROAD_L) / 4.0
	for li in range(1, 4):
		var divx = ROAD_L + lane_w * li
		for i in range(n):
			var m = ColorRect.new()
			m.color = Color(0.85, 0.85, 0.90, 0.22)
			m.size = Vector2(5, MARK_H)
			m.position = Vector2(divx - 2, HUD_H + i * MARK_PER)
			m.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_game_layer.add_child(m)
			_road_marks.append({node=m, base_i=i, lane=li})

func _scroll_marks(delta: float):
	_scroll += _speed * delta
	var road_h = VH - HUD_H + MARK_PER
	var lane_w = (ROAD_R - ROAD_L) / 4.0
	for mk in _road_marks:
		var divx = ROAD_L + lane_w * mk.lane
		mk.node.position.x = divx - 2
		var y = HUD_H + fmod(mk.base_i * MARK_PER + _scroll, road_h) - MARK_PER
		mk.node.position.y = y

func _spawn_player():
	var car_def = _get_selected_car_def()
	_player = _make_car(car_def.col, car_def.acc, true)
	_player.position = Vector2(_player_x - CAR_W * 0.5, VH * 0.72)
	_game_layer.add_child(_player)

func _get_selected_car_def() -> Dictionary:
	var sel = SettingsManager.race_selected if SettingsManager else "blue"
	for d in CAR_DEFS:
		if d.id == sel:
			return d
	return CAR_DEFS[0]

func _build_hud():
	var hud = ColorRect.new()
	hud.color = Color("#080C18")
	hud.color.a = 0.97
	hud.position = Vector2(0, 0)
	hud.size = Vector2(VW, HUD_H)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)

	var sep = ColorRect.new()
	sep.color = Color(0.28, 0.36, 0.52, 0.60)
	sep.position = Vector2(0, HUD_H - 2)
	sep.size = Vector2(VW, 2)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sep)

	_hud_lives = _hud_lbl(140, 20, "❤ ❤ ❤",    Color("#B04040"), 17)
	_hud_score = _hud_lbl(310, 20, "Score: 0",  Color("#C89A18"), 17)
	_hud_coins = _hud_lbl(488, 20, "Coins: 0",  Color("#B07818"), 17)
	_hud_speed = _hud_lbl(656, 20, "Speed: 220",Color("#3A7A50"), 17)
	_hud_qtmr  = _hud_lbl(820, 16, "Q: 15s",    Color("#3A6880"), 19)

	var shop_btn = Button.new()
	shop_btn.text = "🏪 Shop"
	shop_btn.position = Vector2(940, 10)
	shop_btn.custom_minimum_size = Vector2(100, 46)
	var ss = StyleBoxFlat.new()
	ss.bg_color = Color("#120820")
	ss.border_color = Color("#503068")
	ss.set_border_width_all(2)
	ss.set_corner_radius_all(8)
	ss.content_margin_left = 8
	ss.content_margin_right = 8
	ss.content_margin_top = 6
	ss.content_margin_bottom = 6
	shop_btn.add_theme_stylebox_override("normal", ss)
	shop_btn.add_theme_color_override("font_color", Color("#9070B8"))
	shop_btn.add_theme_font_size_override("font_size", 13)
	add_child(shop_btn)
	shop_btn.pressed.connect(_show_shop)

func _hud_lbl(x: float, y: float, txt: String, col: Color, sz: int) -> Label:
	var l = Label.new()
	l.text = txt
	l.position = Vector2(x, y)
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l

func _refresh_hud():
	var h = ""
	for _i in range(_lives):
		h += "❤ "
	_hud_lives.text = h.strip_edges() if _lives > 0 else "—"
	_hud_score.text = "Score: " + str(_score)
	_hud_coins.text = "Coins: " + str(_coins)
	_hud_speed.text = "Speed: " + str(int(_speed))
	_hud_qtmr.text  = "Q: " + str(int(maxf(_qtimer, 0.0))) + "s"
	if _qtimer < 5.0:
		_hud_qtmr.add_theme_color_override("font_color", Color("#A03030"))
	elif _qtimer < 10.0:
		_hud_qtmr.add_theme_color_override("font_color", Color("#AA6818"))
	else:
		_hud_qtmr.add_theme_color_override("font_color", Color("#3A6880"))

func _spawn_logic(delta: float):
	_spawn_t += delta
	if _spawn_t >= _spawn_iv:
		_spawn_t = 0.0
		_spawn_iv = maxf(0.8, _spawn_iv - 0.018)
		_spawn_enemy()
		if randf() > 0.50:
			_spawn_enemy()
	_ctimer += delta
	if _ctimer >= _coin_iv:
		_ctimer = 0.0
		_spawn_coin()

func _spawn_enemy():
	var lane = randi() % 4
	var cx   = LANE_CX[lane]
	var col  = [
		Color("#2A1818"), Color("#181828"), Color("#202818"),
		Color("#281818"), Color("#1A1A20"), Color("#201818"),
	].pick_random()
	var en = _make_car(col, col.lightened(0.28), false)
	en.position = Vector2(cx - CAR_W * 0.5, HUD_H - CAR_H - 8)
	_game_layer.add_child(en)
	_enemies.append({node=en, smult=randf_range(0.80, 1.35)})

func _spawn_coin():
	var lane = LANE_CX[randi() % 4]
	var cy   = randf_range(HUD_H + 80, VH * 0.60)
	var coin = _make_coin()
	coin.position = Vector2(lane - COIN_R, cy - COIN_R)
	_game_layer.add_child(coin)
	_coin_nodes.append({node=coin, active=true})

func _move_enemies(delta: float):
	for i in range(_enemies.size() - 1, -1, -1):
		var e = _enemies[i]
		e.node.position.y += _speed * e.smult * delta
		if e.node.position.y > DESPAWN_Y:
			e.node.queue_free()
			_enemies.remove_at(i)

func _check_collisions():
	if _crash_pending:
		return
	var px = _player.position.x
	var py = _player.position.y
	var hm = 10.0

	for i in range(_enemies.size() - 1, -1, -1):
		var e = _enemies[i]
		if _rects_overlap(
			px + hm, py + hm, CAR_W - hm * 2, CAR_H - hm * 2,
			e.node.position.x + hm, e.node.position.y + hm, CAR_W - hm * 2, CAR_H - hm * 2
		):
			_enemies.remove_at(i)
			_on_crash(e.node)
			return

	for i in range(_coin_nodes.size() - 1, -1, -1):
		var c = _coin_nodes[i]
		if not c.active:
			continue
		var cx = c.node.position.x + COIN_R
		var cy2 = c.node.position.y + COIN_R
		var pcx = px + CAR_W * 0.5
		var pcy = py + CAR_H * 0.5
		if Vector2(pcx - cx, pcy - cy2).length() < CAR_W * 0.42 + COIN_R:
			c.active = false
			c.node.queue_free()
			_coin_nodes.remove_at(i)
			_collect_coin()

static func _rects_overlap(ax:float,ay:float,aw:float,ah:float,
							bx:float,by:float,bw:float,bh:float) -> bool:
	return ax < bx + bw and ax + aw > bx and ay < by + bh and ay + ah > by

func _on_crash(crashed_node: Control):
	if _crash_pending:
		return
	_crash_pending = true
	_gs = GS.CRASH_Q
	if is_instance_valid(crashed_node):
		crashed_node.queue_free()
	StyleManager.screen_flash(self, Color(0.80, 0.10, 0.10))
	_lives -= 1
	var am = get_node_or_null("/root/AudioManager")
	if am:
		am.play("wrong")
	if _lives <= 0:
		await get_tree().create_timer(0.6).timeout
		if not is_instance_valid(self):
			return
		_crash_pending = false
		_do_game_over()
		return
	await get_tree().create_timer(0.55).timeout
	if not is_instance_valid(self):
		return
	_crash_pending = false
	_show_question(true)

func _collect_coin():
	_coins += 1
	_score += 10
	StyleManager.spawn_score_popup(_game_layer, _player.position + Vector2(0, -30), 10, true)
	var am = get_node_or_null("/root/AudioManager")
	if am:
		am.play("combo")

func _show_question(from_crash: bool):
	_gs = GS.CRASH_Q if from_crash else GS.QUESTION
	var q = QUESTIONS[_q_order[_q_idx % _q_order.size()]]
	_q_idx += 1

	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.z_index = 70
	add_child(dim)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(820, 480)
	panel.z_index = 71
	panel.scale = Vector2(0.5, 0.5)
	panel.modulate.a = 0.0
	panel.position = Vector2((VW - 820) * 0.5, (VH - 480) * 0.5)
	add_child(panel)

	var pst = StyleBoxFlat.new()
	pst.bg_color = Color("#080E18")
	pst.border_color = Color("#6A2020") if from_crash else Color("#203050")
	pst.set_border_width_all(3)
	pst.set_corner_radius_all(14)
	pst.content_margin_left = 28
	pst.content_margin_right = 28
	pst.content_margin_top  = 22
	pst.content_margin_bottom = 22
	pst.shadow_color = Color(0,0,0,0.70)
	pst.shadow_size = 12
	pst.shadow_offset = Vector2(5,7)
	panel.add_theme_stylebox_override("panel", pst)

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)

	var hdr = Label.new()
	hdr.text = "💥  CRASH — ANSWER TO RECOVER!" if from_crash else "⏱  CYBERSECURITY QUESTION"
	hdr.add_theme_font_size_override("font_size", 21)
	hdr.add_theme_color_override("font_color", Color("#C03030") if from_crash else Color("#3A6888"))
	vb.add_child(hdr)

	if from_crash:
		var note = Label.new()
		note.text = "Correct = life restored.  Wrong = -1 more life."
		note.add_theme_font_size_override("font_size", 13)
		note.add_theme_color_override("font_color", Color("#907020"))
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(note)

	var ln = ColorRect.new()
	ln.color = Color("#182030")
	ln.custom_minimum_size = Vector2(0, 2)
	ln.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(ln)

	var ql = Label.new()
	ql.text = q.q
	ql.add_theme_font_size_override("font_size", 19)
	ql.add_theme_color_override("font_color", Color("#C8D8E8"))
	ql.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(ql)

	var btn_bgs  = ["#2A0800", "#080020", "#001808", "#181000"]
	var letters  = ["A", "B", "C", "D"]
	var answered = [false]
	var answer_btns: Array = []

	for i in range(4):
		var ab = Button.new()
		ab.text = letters[i] + ")  " + q.opts[i]
		ab.custom_minimum_size = Vector2(760, 50)
		StyleManager.style_button(ab, btn_bgs[i], "#B8C8D8")
		ab.add_theme_font_size_override("font_size", 15)
		vb.add_child(ab)
		answer_btns.append(ab)
		var ci = i
		ab.pressed.connect(func():
			if answered[0]:
				return
			answered[0] = true
			var correct = (ci == q.correct)
			ab.add_theme_color_override("font_color",
				Color("#40B860") if correct else Color("#B84040"))
			for btn in answer_btns:
				btn.disabled = true
			if not correct:
				answer_btns[q.correct].add_theme_color_override("font_color", Color("#40B860"))
				var hint_lbl = Label.new()
				hint_lbl.text = "💡 " + q.hint
				hint_lbl.add_theme_font_size_override("font_size", 13)
				hint_lbl.add_theme_color_override("font_color", Color("#907020"))
				hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				vb.add_child(hint_lbl)
			_apply_answer(correct, from_crash, dim, panel)
		)

	var hint_btn = Button.new()
	hint_btn.text = "💡 Show Hint  (5 coins)"
	hint_btn.custom_minimum_size = Vector2(220, 38)
	StyleManager.style_button(hint_btn, "#28200A", "#B09020")
	hint_btn.add_theme_font_size_override("font_size", 13)
	vb.add_child(hint_btn)
	var hint_shown = [false]
	hint_btn.pressed.connect(func():
		if hint_shown[0]:
			return
		hint_shown[0] = true
		if _coins >= 5:
			_coins -= 5
		hint_btn.text = "💡 " + q.hint
		hint_btn.disabled = true
	)

	var tw = create_tween()
	tw.set_ease(Tween.EASE_OUT)
	tw.set_trans(Tween.TRANS_BACK)
	tw.tween_property(dim,   "color:a",    0.72, 0.18)
	tw.parallel().tween_property(panel, "scale",      Vector2(1, 1), 0.28)
	tw.parallel().tween_property(panel, "modulate:a", 1.0,           0.28)

func _apply_answer(correct: bool, was_crash: bool, dim: ColorRect, panel: PanelContainer):
	var am = get_node_or_null("/root/AudioManager")
	if correct:
		_score += 25
		if was_crash:
			_lives = mini(_lives + 1, 5)
		StyleManager.screen_flash(self, Color(0.10, 0.65, 0.25))
		if am:
			am.play("correct")
	else:
		_lives -= 1
		StyleManager.screen_flash(self, Color(0.70, 0.10, 0.10))
		if am:
			am.play("wrong")

	await get_tree().create_timer(2.5).timeout
	if not is_instance_valid(self):
		return

	var tw = create_tween()
	tw.set_ease(Tween.EASE_IN)
	tw.tween_property(panel, "scale",      Vector2(0.5, 0.5), 0.18)
	tw.parallel().tween_property(panel, "modulate:a", 0.0,           0.18)
	tw.parallel().tween_property(dim,   "color:a",    0.0,           0.18)
	tw.tween_callback(func():
		if is_instance_valid(panel):
			panel.queue_free()
		if is_instance_valid(dim):
			dim.queue_free()
		if _lives <= 0:
			_do_game_over()
		else:
			_gs = GS.PLAYING
	)

func _do_game_over():
	_gs = GS.GAME_OVER
	if SettingsManager:
		SettingsManager.race_coins += _coins
		SettingsManager.save_settings()
	var am = get_node_or_null("/root/AudioManager")
	if am:
		am.play("game_over")

	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.z_index = 80
	add_child(dim)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(680, 440)
	panel.z_index = 81
	panel.scale = Vector2(0.5, 0.5)
	panel.modulate.a = 0.0
	panel.position = Vector2((VW - 680) * 0.5, (VH - 440) * 0.5)
	add_child(panel)

	var pst = StyleBoxFlat.new()
	pst.bg_color = Color("#080E18")
	pst.border_color = Color("#6A2020")
	pst.set_border_width_all(3)
	pst.set_corner_radius_all(14)
	pst.content_margin_left = 32
	pst.content_margin_right = 32
	pst.content_margin_top  = 26
	pst.content_margin_bottom = 26
	pst.shadow_color = Color(0,0,0,0.75)
	pst.shadow_size = 14
	pst.shadow_offset = Vector2(5,7)
	panel.add_theme_stylebox_override("panel", pst)

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	panel.add_child(vb)

	var t1 = Label.new()
	t1.text = "GAME OVER"
	t1.add_theme_font_size_override("font_size", 44)
	t1.add_theme_color_override("font_color", Color("#BB3030"))
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t1)

	var total = SettingsManager.race_coins if SettingsManager else _coins
	var t2 = Label.new()
	t2.text = "Score: " + str(_score) + "   Coins earned: " + str(_coins) + "   Total: " + str(total)
	t2.add_theme_font_size_override("font_size", 17)
	t2.add_theme_color_override("font_color", Color("#C0901A"))
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t2)

	var ln = ColorRect.new()
	ln.color = Color("#182030")
	ln.custom_minimum_size = Vector2(0, 2)
	ln.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(ln)

	var retry = Button.new()
	retry.text = "  PLAY AGAIN  "
	retry.custom_minimum_size = Vector2(300, 52)
	StyleManager.style_button(retry, "#1A4828", "#FFFFFF")
	vb.add_child(retry)

	var shop = Button.new()
	shop.text = "  🏪 CAR SHOP  "
	shop.custom_minimum_size = Vector2(300, 52)
	StyleManager.style_button(shop, "#2E1848", "#DDBBFF")
	vb.add_child(shop)

	var menu = Button.new()
	menu.text = "  ← Mission Select  "
	menu.custom_minimum_size = Vector2(300, 52)
	StyleManager.style_button(menu, "#102038", "#88AACC")
	vb.add_child(menu)

	var quit_btn = Button.new()
	quit_btn.text = "  ✕ Quit Game  "
	quit_btn.custom_minimum_size = Vector2(300, 52)
	StyleManager.style_button(quit_btn, "#2A0A0A", "#CC6666")
	vb.add_child(quit_btn)

	var tw = create_tween()
	tw.set_ease(Tween.EASE_OUT)
	tw.set_trans(Tween.TRANS_BACK)
	tw.tween_property(dim,   "color:a",    0.80, 0.22)
	tw.parallel().tween_property(panel, "scale",      Vector2(1, 1), 0.32)
	tw.parallel().tween_property(panel, "modulate:a", 1.0,           0.32)

	retry.pressed.connect(func():
		panel.queue_free()
		dim.queue_free()
		get_tree().reload_current_scene()
	)
	shop.pressed.connect(func():
		panel.queue_free()
		dim.queue_free()
		_show_shop()
	)
	menu.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/mission_select.tscn")
	)
	quit_btn.pressed.connect(get_tree().quit)

func _show_shop():
	var prev_gs = _gs
	_gs = GS.SHOP

	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.z_index = 75
	add_child(dim)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(900, 480)
	panel.z_index = 76
	panel.scale = Vector2(0.5, 0.5)
	panel.modulate.a = 0.0
	panel.position = Vector2((VW - 900) * 0.5, (VH - 480) * 0.5)
	add_child(panel)

	var pst = StyleBoxFlat.new()
	pst.bg_color = Color("#080E18")
	pst.border_color = Color("#3A2058")
	pst.set_border_width_all(3)
	pst.set_corner_radius_all(14)
	pst.content_margin_left = 30
	pst.content_margin_right = 30
	pst.content_margin_top  = 24
	pst.content_margin_bottom = 24
	pst.shadow_color = Color(0,0,0,0.75)
	pst.shadow_size = 14
	pst.shadow_offset = Vector2(5,7)
	panel.add_theme_stylebox_override("panel", pst)

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)

	var hdr = Label.new()
	hdr.text = "🏪  CAR SHOP"
	hdr.add_theme_font_size_override("font_size", 28)
	hdr.add_theme_color_override("font_color", Color("#7050A8"))
	vb.add_child(hdr)

	var total_coins = SettingsManager.race_coins if SettingsManager else 0
	var bal = Label.new()
	bal.text = "Your Coins: " + str(total_coins)
	bal.add_theme_font_size_override("font_size", 16)
	bal.add_theme_color_override("font_color", Color("#B08018"))
	vb.add_child(bal)

	var ln = ColorRect.new()
	ln.color = Color("#182030")
	ln.custom_minimum_size = Vector2(0, 2)
	ln.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(ln)

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	vb.add_child(row)

	var owned    = SettingsManager.race_owned    if SettingsManager else ["blue"]
	var selected = SettingsManager.race_selected if SettingsManager else "blue"

	for car in CAR_DEFS:
		var card = VBoxContainer.new()
		card.add_theme_constant_override("separation", 6)
		card.custom_minimum_size = Vector2(158, 0)
		row.add_child(card)

		var preview = _make_car(car.col, car.acc, false)
		preview.scale = Vector2(0.75, 0.75)
		card.add_child(preview)

		var name_l = Label.new()
		name_l.text = car.label
		name_l.add_theme_font_size_override("font_size", 12)
		name_l.add_theme_color_override("font_color", car.col.lightened(0.4))
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(name_l)

		var is_owned    = car.id in owned
		var is_selected = car.id == selected

		var act_btn = Button.new()
		if is_selected:
			act_btn.text = "✓ SELECTED"
			StyleManager.style_button(act_btn, "#0A2A18", "#50A870")
		elif is_owned:
			act_btn.text = "SELECT"
			StyleManager.style_button(act_btn, "#0E2038", "#6090BB")
		else:
			act_btn.text = "BUY  " + str(car.price)
			var can_buy = (total_coins >= car.price)
			StyleManager.style_button(act_btn, "#20103A" if can_buy else "#14141E", "#9070B8")
			act_btn.disabled = not can_buy
		act_btn.add_theme_font_size_override("font_size", 12)
		act_btn.custom_minimum_size = Vector2(148, 38)
		card.add_child(act_btn)

		var car_id = car.id
		var car_price = car.price
		act_btn.pressed.connect(func():
			if not (car_id in (SettingsManager.race_owned if SettingsManager else ["blue"])):
				if SettingsManager:
					SettingsManager.race_coins -= car_price
					SettingsManager.race_owned.append(car_id)
			if SettingsManager:
				SettingsManager.race_selected = car_id
				SettingsManager.save_settings()
			panel.queue_free()
			dim.queue_free()
			_gs = prev_gs
			if is_instance_valid(_player):
				_player.queue_free()
			_player_x = LANE_CX[1]
			_spawn_player()
			_show_shop()
		)

	var close = Button.new()
	close.text = "  CLOSE  "
	close.custom_minimum_size = Vector2(220, 48)
	StyleManager.style_button(close, "#102038", "#88AACC")
	vb.add_child(close)
	close.pressed.connect(func():
		panel.queue_free()
		dim.queue_free()
		_gs = prev_gs
	)

	var tw = create_tween()
	tw.set_ease(Tween.EASE_OUT)
	tw.set_trans(Tween.TRANS_BACK)
	tw.tween_property(dim,   "color:a",    0.75, 0.18)
	tw.parallel().tween_property(panel, "scale",      Vector2(1, 1), 0.28)
	tw.parallel().tween_property(panel, "modulate:a", 1.0,           0.28)

func _show_tutorial():
	_gs = GS.TUTORIAL
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.z_index = 85
	add_child(dim)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(820, 500)
	panel.z_index = 86
	panel.scale = Vector2(0.5, 0.5)
	panel.modulate.a = 0.0
	panel.position = Vector2((VW - 820) * 0.5, (VH - 500) * 0.5)
	add_child(panel)

	var pst = StyleBoxFlat.new()
	pst.bg_color = Color("#080E18")
	pst.border_color = Color("#203050")
	pst.set_border_width_all(3)
	pst.set_corner_radius_all(14)
	pst.content_margin_left = 32
	pst.content_margin_right = 32
	pst.content_margin_top  = 26
	pst.content_margin_bottom = 26
	pst.shadow_color = Color(0,0,0,0.75)
	pst.shadow_size = 14
	pst.shadow_offset = Vector2(5,7)
	panel.add_theme_stylebox_override("panel", pst)

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)

	var t = Label.new()
	t.text = "🏎  HOW TO PLAY — CYBER RACER"
	t.add_theme_font_size_override("font_size", 24)
	t.add_theme_color_override("font_color", Color("#4A7898"))
	vb.add_child(t)

	var ln2 = ColorRect.new()
	ln2.color = Color("#182030")
	ln2.custom_minimum_size = Vector2(0,2)
	ln2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(ln2)

	var tips = [
		["← → Arrow Keys / A D",  "Steer across 4 lanes — dodge enemy vehicles"],
		["↑ Arrow / W",            "Accelerate — higher speed earns more score per second"],
		["↓ Arrow / S",            "Brake — slow down to dodge more easily"],
		["💥 Crash",                "-1 life + cybersecurity question. Answer correctly to restore life!"],
		["⏱ Every 15 seconds",     "A question appears. Wrong = -1 life. Stay alert!"],
		["🪙 Gold coins on road",  "Drive over them. Use coins in the Shop to buy cars."],
		["🏪 Shop button",          "Buy and equip different cars with coins"],
		["📱 Mobile",               "Use on-screen ◀ ▶ ▲ ▼ buttons to control the car"],
	]
	for tip in tips:
		var row2 = HBoxContainer.new()
		row2.add_theme_constant_override("separation", 10)
		vb.add_child(row2)
		var k = Label.new()
		k.text = tip[0]
		k.add_theme_font_size_override("font_size", 14)
		k.add_theme_color_override("font_color", Color("#B8961A"))
		k.custom_minimum_size = Vector2(210, 0)
		row2.add_child(k)
		var v = Label.new()
		v.text = tip[1]
		v.add_theme_font_size_override("font_size", 14)
		v.add_theme_color_override("font_color", Color("#7898B0"))
		v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.custom_minimum_size = Vector2(510, 0)
		row2.add_child(v)

	var play = Button.new()
	play.text = "  START RACING!  "
	play.custom_minimum_size = Vector2(280, 50)
	StyleManager.style_button(play, "#1A3828", "#88C8A0")
	vb.add_child(play)
	play.pressed.connect(func():
		var tw2 = create_tween()
		tw2.set_ease(Tween.EASE_IN)
		tw2.tween_property(panel, "scale",      Vector2(0.5, 0.5), 0.18)
		tw2.parallel().tween_property(panel, "modulate:a", 0.0,           0.18)
		tw2.parallel().tween_property(dim,   "color:a",    0.0,           0.18)
		tw2.tween_callback(func():
			panel.queue_free()
			dim.queue_free()
			_gs = GS.PLAYING
		)
	)

	var tw = create_tween()
	tw.set_ease(Tween.EASE_OUT)
	tw.set_trans(Tween.TRANS_BACK)
	tw.tween_property(dim,   "color:a",    0.75, 0.22)
	tw.parallel().tween_property(panel, "scale",      Vector2(1, 1), 0.32)
	tw.parallel().tween_property(panel, "modulate:a", 1.0,           0.32)

static func _r(p: Control, x: float, y: float, w: float, h: float, c: Color) -> ColorRect:
	var rect = ColorRect.new()
	rect.position = Vector2(x, y)
	rect.size = Vector2(w, h)
	rect.color = c
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(rect)
	return rect

static func _wheel(p: Control, x: float, y: float, w: float, h: float):
	_r(p, x,   y,       w,   h,   Color(0.07, 0.07, 0.09))
	_r(p, x+1, y+2,     w-2, h-4, Color(0.50, 0.52, 0.56))
	_r(p, x+2, y+h/2-3, w-4, 6,   Color(0.28, 0.28, 0.32))
	_r(p, x+1, y+2,     w-2, 2,   Color(0.72, 0.74, 0.78, 0.55))
	_r(p, x+1, y+h/2-1, w-2, 2,   Color(0.42, 0.44, 0.48, 0.65))

static func _make_car(body: Color, accent: Color, is_player: bool) -> Control:
	var W = CAR_W
	var H = CAR_H
	var c = Control.new()
	c.custom_minimum_size = Vector2(W, H)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var dark = body.darkened(0.38)
	var mid  = body.darkened(0.16)
	var lite = body.lightened(0.18)

	_r(c, -4,  H*0.10, 10, 24, Color(0,0,0,0.20))
	_r(c, W-6, H*0.10, 10, 24, Color(0,0,0,0.20))
	_r(c, -4,  H*0.62, 10, 24, Color(0,0,0,0.20))
	_r(c, W-6, H*0.62, 10, 24, Color(0,0,0,0.20))

	_r(c, 5,   H-10,   W-10, 10,     dark)
	_r(c, 3,   H-30,   W-6,  20,     mid)
	_r(c, 1,   H*0.36, W-2,  H*0.38, body)
	_r(c, 3,   10,     W-6,  H*0.25, mid)
	_r(c, 5,   0,      W-10, 10,     dark)

	_r(c, W/2-2, 12, 4, H*0.21, dark)
	_r(c, 7,  16, 8, 4, dark.lightened(0.08))
	_r(c, 7,  22, 8, 4, dark.lightened(0.05))
	_r(c, W-15, 16, 8, 4, dark.lightened(0.08))
	_r(c, W-15, 22, 8, 4, dark.lightened(0.05))

	var rx = 10.0
	var rw = W - 20.0
	_r(c, rx,     H*0.32, 5, H*0.06, dark)
	_r(c, W-rx-5, H*0.32, 5, H*0.06, dark)
	_r(c, rx,     H*0.28, rw, H*0.13, Color(0.24, 0.38, 0.60, 0.62))
	_r(c, rx-2,   H*0.41, rw+4, H*0.22, lite)
	_r(c, rx+3,   H*0.43, rw-6, H*0.18, dark)
	_r(c, rx,     H*0.62, 5, H*0.05, dark)
	_r(c, W-rx-5, H*0.62, 5, H*0.05, dark)
	_r(c, rx,     H*0.64, rw, H*0.10, Color(0.20, 0.32, 0.52, 0.52))

	_r(c, 1,    H*0.56, W-2, 2,   dark)
	_r(c, 6,    H*0.50, 10,  4,   dark.lightened(0.15))
	_r(c, W-16, H*0.50, 10,  4,   dark.lightened(0.15))
	_r(c, 1,    H-32,   W-2, 3,   dark)

	_wheel(c, -8, H*0.10, 10, 24)
	_wheel(c, W-2, H*0.10, 10, 24)
	_wheel(c, -8, H*0.62, 10, 24)
	_wheel(c, W-2, H*0.62, 10, 24)

	var arch = dark.darkened(0.15)
	_r(c, 0,   H*0.08, 5, 28, arch)
	_r(c, W-5, H*0.08, 5, 28, arch)
	_r(c, 0,   H*0.60, 5, 28, arch)
	_r(c, W-5, H*0.60, 5, 28, arch)

	_r(c, 4,    1, 18, 8, Color(0.95, 0.90, 0.68, 0.95))
	_r(c, W-22, 1, 18, 8, Color(0.95, 0.90, 0.68, 0.95))
	_r(c, 6,    1, 9,  5, Color(0.70, 0.82, 1.00, 0.80))
	_r(c, W-15, 1, 9,  5, Color(0.70, 0.82, 1.00, 0.80))

	_r(c, 4,    H-9, 18, 8, Color(0.82, 0.10, 0.10, 0.95))
	_r(c, W-22, H-9, 18, 8, Color(0.82, 0.10, 0.10, 0.95))
	_r(c, W/2-6, H-8, 12, 6, Color(0.95, 0.65, 0.20, 0.70))

	_r(c, W/2-10, H-4, 7, 4, Color(0.08, 0.08, 0.10))
	_r(c, W/2+3,  H-4, 7, 4, Color(0.08, 0.08, 0.10))

	_r(c, W/2-2, H*0.12, 5, H*0.76, Color(accent.r, accent.g, accent.b, 0.28))

	_r(c, -6,  H*0.31, 6, 8, mid.darkened(0.12))
	_r(c, W,   H*0.31, 6, 8, mid.darkened(0.12))

	if is_player:
		_r(c, 4, H, W-8, 4, Color(accent.r, accent.g, accent.b, 0.45))

	return c

static func _make_coin() -> Control:
	var D = COIN_R * 2
	var c = Control.new()
	c.custom_minimum_size = Vector2(D, D)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var offsets = [Vector2(5,0), Vector2(0,5), Vector2(5,5), Vector2(10,5), Vector2(5,10)]
	for off in offsets:
		var sq = ColorRect.new()
		sq.color = Color("#9A7015")
		sq.size = Vector2(11, 11)
		sq.position = off
		sq.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(sq)
	var hl = ColorRect.new()
	hl.color = Color(1.0, 0.88, 0.50, 0.55)
	hl.size = Vector2(7, 5)
	hl.position = Vector2(7, 3)
	hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(hl)
	var lbl = Label.new()
	lbl.text = "$"
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color("#C89820"))
	lbl.position = Vector2(4, 2)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(lbl)
	return c
