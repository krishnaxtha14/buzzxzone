extends Node

# Inner Node2D that owns all trail/ripple drawing
class TrailPainter extends Node2D:
	var pts:    Array = []   # {p: Vector2, age: float}
	var clicks: Array = []   # {p: Vector2, age: float}
	const PT_LIFE = 0.38
	const CK_LIFE = 0.52

	func tick(delta: float, mp: Vector2):
		pts.append({p = mp, age = 0.0})
		if pts.size() > 30:
			pts.pop_front()
		for i in range(pts.size() - 1, -1, -1):
			pts[i].age += delta
			if pts[i].age > PT_LIFE:
				pts.remove_at(i)
		for i in range(clicks.size() - 1, -1, -1):
			clicks[i].age += delta
			if clicks[i].age > CK_LIFE:
				clicks.remove_at(i)
		queue_redraw()

	func add_click(pos: Vector2):
		clicks.append({p = pos, age = 0.0})

	func _draw():
		# ── Trail ────────────────────────────────────────────────────────────
		for i in range(pts.size()):
			var pt   = pts[i]
			var frac = 1.0 - (pt.age / PT_LIFE)
			var r    = lerp(1.2, 10.0, frac)
			var a    = frac * 0.72
			# Cyan outer glow
			draw_circle(pt.p, r,        Color(0.0, 1.0, 0.9, a))
			# White core
			draw_circle(pt.p, r * 0.4,  Color(1.0, 1.0, 1.0, a * 0.55))

		# ── Click ripples ────────────────────────────────────────────────────
		for ck in clicks:
			var frac = ck.age / CK_LIFE
			var r1   = lerp(5.0, 52.0, frac)
			var r2   = lerp(3.0, 26.0, frac)
			var a    = (1.0 - frac) * 0.9
			draw_arc(ck.p, r1, 0.0, TAU, 36, Color(0.0, 1.0, 0.82, a), 2.2)
			draw_arc(ck.p, r2, 0.0, TAU, 28, Color(1.0, 0.92, 0.0,  a * 0.65), 1.5)
			# Inner burst dot
			draw_circle(ck.p, lerp(6.0, 0.5, frac), Color(1.0, 1.0, 1.0, a * 0.5))

		# ── Custom cursor dot (last trail point == mouse pos) ────────────────
		if pts.size() > 0:
			var c = pts[pts.size() - 1].p
			# Outer ring
			draw_arc(c, 7.0, 0.0, TAU, 24, Color(0.0, 1.0, 1.0, 0.90), 1.8)
			# Inner dot
			draw_circle(c, 2.8, Color(1.0, 1.0, 1.0, 0.98))
			# Crosshair arms
			var arm = 10.0
			var gap = 5.0
			draw_line(c + Vector2(-arm - gap, 0), c + Vector2(-gap, 0),
					  Color(0.0, 1.0, 1.0, 0.75), 1.4)
			draw_line(c + Vector2(gap,  0), c + Vector2(arm + gap, 0),
					  Color(0.0, 1.0, 1.0, 0.75), 1.4)
			draw_line(c + Vector2(0, -arm - gap), c + Vector2(0, -gap),
					  Color(0.0, 1.0, 1.0, 0.75), 1.4)
			draw_line(c + Vector2(0,  gap), c + Vector2(0,  arm + gap),
					  Color(0.0, 1.0, 1.0, 0.75), 1.4)

# ─────────────────────────────────────────────────────────────────────────────

var _canvas:  CanvasLayer
var _painter: TrailPainter
var _hidden:  bool = false

func _ready():
	_canvas       = CanvasLayer.new()
	_canvas.layer = 127
	add_child(_canvas)

	_painter = TrailPainter.new()
	_canvas.add_child(_painter)

	if SettingsManager:
		_hidden = not SettingsManager.cursor_trail
		if SettingsManager.settings_changed.connect(_on_settings_changed) != OK:
			pass

	if not _hidden:
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

func _on_settings_changed():
	set_trail_enabled(SettingsManager.cursor_trail)

func set_trail_enabled(enabled: bool):
	_hidden = not enabled
	if _hidden:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		_painter.pts.clear()
		_painter.clicks.clear()
		_painter.queue_redraw()
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

func _process(delta: float):
	if _hidden:
		return
	var vp = get_viewport()
	if vp:
		_painter.tick(delta, vp.get_mouse_position())

func _input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			# Ripple effect at click position
			if not _hidden:
				var vp = get_viewport()
				if vp:
					_painter.add_click(vp.get_mouse_position())
			# Play click sound globally
			var am = get_node_or_null("/root/AudioManager")
			if am:
				am.play("click")
