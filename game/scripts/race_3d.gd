extends Node3D

# -----------------------------------------------------------------------------
enum GS { TUTORIAL, PLAYING, SHOP, GAME_OVER }

# -- Layout --------------------------------------------------------------------
const LANE_X   = [-6.0, -2.0, 2.0, 6.0]   # 4 lanes
const ROAD_W   = 17.0
const TILE_LEN = 30.0
const N_TILES  = 7
const SPAWN_Z  = -270.0
const DEAD_Z   = 32.0
const WHEEL_R  = 0.44
const CAR_Y    = WHEEL_R        # car node y so wheels touch road

const SPD_DEF  = 22.0
const SPD_MIN  = 8.0
const SPD_MAX  = 52.0
const SPD_ACC  = 2.6

const ENEMY_COLS = [
	Color(0.75,0.12,0.12), Color(0.75,0.44,0.06),
	Color(0.44,0.12,0.66), Color(0.10,0.44,0.72),
	Color(0.10,0.60,0.26), Color(0.22,0.22,0.24),
	Color(0.82,0.82,0.84), Color(0.60,0.44,0.08),
]

# -- State ---------------------------------------------------------------------
var _gs:    int   = GS.TUTORIAL
var _lives: int   = 3
var _score: int   = 0
var _coins: int   = 0
var _speed: float = SPD_DEF
var _inp_x: float = 0.0
var _touch_left:  bool = false
var _touch_right: bool = false
var _touch_up:    bool = false
var _touch_down:  bool = false
var _player_offset: float = LANE_X[1]   # lane position, curve-independent (curve is added on top)
var _world_dist:    float = 0.0   # total distance travelled — the road curve is a fixed
                                   # function of this, so it's a real static track shape,
                                   # not just a cosmetic wobble

# -----------------------------------------------------------------------------
#  Road curve  (a fixed S-curve shape indexed by distance travelled; tiles /
#  traffic / coins bake their offset in once at spawn using the distance they
#  were spawned at, so a piece of road never moves sideways after being
#  placed — only the player's target curve-position advances every frame)
# -----------------------------------------------------------------------------
func _curve_x(d: float) -> float:
	return sin(d * 0.0035 + 0.6) * 9.0 + sin(d * 0.0012 + 2.1) * 5.0

func _curve_slope(d: float) -> float:
	return 9.0 * 0.0035 * cos(d * 0.0035 + 0.6) + 5.0 * 0.0012 * cos(d * 0.0012 + 2.1)
var _tilt:  float = 0.0
var _cam_x: float = 0.0
var _obs_t: float = 0.0
var _obs_iv: float = 2.8
var _cot:   float = 0.0
var _coiv:  float = 3.6

var _cam:           Camera3D
var _player:        Node3D
var _trail:         CPUParticles3D
var _engine_player: AudioStreamPlayer3D
var _tiles:         Array = []
var _obs:           Array = []
var _coins3:        Array = []
var _clouds:        Array = []   # animated cloud meshes

var _hud:       CanvasLayer
var _l_lives:   Label
var _l_score:   Label
var _l_coins:   Label
var _l_speed:   Label
var _spd_fill:  ColorRect

# -----------------------------------------------------------------------------
func _ready():
	_coins = SettingsManager.race_coins if SettingsManager else 0
	_setup_world()
	_setup_camera()
	_setup_lights()
	_build_backdrop()
	_build_clouds()
	_init_tiles()
	_build_player()
	_build_trail()
	_build_rain()
	_build_hud()
	_show_tutorial_full()

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()

func _process(delta: float):
	_update_clouds(delta)
	if _gs != GS.PLAYING: return
	_handle_input(delta)
	_move_world(delta)
	_spawn_logic(delta)
	_coin_spin(delta)
	_check_collisions()
	_score += int(delta * _speed * 3.0)
	_smooth_cam(delta)
	_refresh_hud(delta)
	_update_engine_sound()

func _update_engine_sound():
	if not is_instance_valid(_engine_player): return
	# Pitch rises with speed: 0.75 at min speed  2.8 at max speed
	var ratio = clampf((_speed - SPD_MIN) / (SPD_MAX - SPD_MIN), 0.0, 1.0)
	_engine_player.pitch_scale = 0.75 + ratio * 2.05

# -----------------------------------------------------------------------------
#  Input
# -----------------------------------------------------------------------------
func _handle_input(delta: float):
	var hi = 0.0
	if Input.is_action_pressed("ui_left")  or Input.is_key_pressed(KEY_A) or _touch_left:  hi -= 1.0
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D) or _touch_right: hi += 1.0
	_inp_x = lerpf(_inp_x, hi, 12.0 * delta)
	_player_offset = clampf(
		_player_offset + _inp_x * 10.5 * delta,
		LANE_X[0] - 0.4, LANE_X[3] + 0.4
	)
	# The road curve is a live function of distance travelled — the player has
	# to keep steering (adjusting _player_offset) to stay on it, same as the
	# baked-in offset every tile/car got at spawn eventually lines up with.
	_player.position.x = _player_offset + _curve_x(_world_dist)
	_player.rotation.y = atan(_curve_slope(_world_dist))
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W) or _touch_up:
		_speed = minf(_speed + SPD_ACC * delta, SPD_MAX)   # fixed: was wrong delta*55*delta
	elif Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S) or _touch_down:
		_speed = maxf(_speed - SPD_ACC * delta, SPD_MIN)
	else:
		_speed = lerpf(_speed, SPD_DEF, 0.35 * delta)
	_tilt = lerpf(_tilt, -_inp_x * 6.5, 7.0 * delta)
	_player.rotation_degrees.z = _tilt

# -----------------------------------------------------------------------------
#  World / environment
# -----------------------------------------------------------------------------
func _setup_world():
	var we  = WorldEnvironment.new()
	var env = Environment.new()

	# Dramatic DUSK / TWILIGHT sky — visible, colourful, cinematic
	env.background_mode = Environment.BG_SKY
	var sky = Sky.new()
	var sm  = ProceduralSkyMaterial.new()
	sm.sky_top_color     = Color(0.06, 0.08, 0.28)    # deep indigo zenith
	sm.sky_horizon_color = Color(0.72, 0.30, 0.08)    # warm orange horizon glow
	sm.sky_curve         = 0.15
	sm.ground_bottom_color  = Color(0.04, 0.04, 0.08)
	sm.ground_horizon_color = Color(0.40, 0.15, 0.04) # ember glow at ground
	sm.ground_curve      = 0.10
	sm.sun_angle_max     = 8.0
	sm.sun_curve         = 0.12
	sky.sky_material = sm
	env.sky = sky

	# Warm dusk ambient — bright enough to see everything clearly
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.10

	# Glow — optimised for gl_compatibility (keep threshold high)
	env.glow_enabled       = true
	env.glow_normalized    = true
	env.glow_intensity     = 0.65
	env.glow_bloom         = 0.08
	env.glow_hdr_threshold = 1.20
	env.glow_blend_mode    = Environment.GLOW_BLEND_MODE_SOFTLIGHT

	# Filmic tone mapping
	env.tonemap_mode     = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.10
	env.tonemap_white    = 1.60

	# Very light atmospheric haze for depth
	env.fog_enabled     = true
	env.fog_density     = 0.0008
	env.fog_light_color = Color(0.55, 0.28, 0.10)
	env.fog_sun_scatter = 0.30

	we.environment = env
	add_child(we)

# Permanent distant city skyline on the horizon — does NOT tile with road
# NOTE: kept to one MeshInstance3D per building (mild window-glow emission on the
# body itself, instead of dozens of individual window meshes) — this is what the
# scene's frame rate mostly lives or dies on, since backdrop buildings are numerous.
func _build_backdrop():
	# Three rings of backdrop buildings — near, mid, far — filling the full horizon
	var rng = RandomNumberGenerator.new(); rng.seed = 99
	var rings = [
		{count=7,  z_min=-130.0, z_max=-80.0,  x_spread=140.0, h_min=12.0, h_max=35.0},
		{count=10, z_min=-220.0, z_max=-140.0, x_spread=200.0, h_min=20.0, h_max=65.0},
		{count=8,  z_min=-400.0, z_max=-230.0, x_spread=280.0, h_min=30.0, h_max=90.0},
	]
	for ring in rings:
		for _i in range(ring.count):
			var bx  = rng.randf_range(-ring.x_spread, ring.x_spread)
			var bz  = rng.randf_range(ring.z_min, ring.z_max)
			var bw  = rng.randf_range(10.0, 28.0)
			var bh  = rng.randf_range(ring.h_min, ring.h_max)
			var bd  = rng.randf_range(8.0, 16.0)
			var grey = rng.randf_range(0.12, 0.22)
			var dark = Color(grey * 0.80, grey * 0.85, grey)
			var wc = Color(rng.randf_range(0.75,1.0), rng.randf_range(0.65,0.90), rng.randf_range(0.25,0.60))
			var body = _box(Vector3(bw, bh, bd), dark, 0.10, wc, 0.30, 0.88)
			body.position = Vector3(bx, bh * 0.5, bz); add_child(body)
	# Wide flat ground plane filling the far distance
	var far_ground = _box(Vector3(600, 0.5, 500), Color(0.16,0.40,0.08), 0.0, Color.BLACK, 0, 0.95)
	far_ground.position = Vector3(0, -0.25, -200.0); add_child(far_ground)

func _setup_camera():
	_cam = Camera3D.new()
	_cam.fov           = 72.0
	_cam.near          = 0.12
	_cam.far           = 600.0
	_cam.position      = Vector3(0, 3.2, 7.8)   # lower + closer = more immersive
	_cam.rotation_degrees = Vector3(-10.0, 0, 0)
	# DOF blur disabled — costly post-process pass for very little visual
	# payoff on gl_compatibility/mobile, and this scene needs the frame budget.
	add_child(_cam)

func _smooth_cam(delta: float):
	_cam_x = lerpf(_cam_x, _player.position.x * 0.50, 7.0 * delta)
	_cam.position.x = _cam_x
	var look = Vector3(_player.position.x * 0.32, 0.8, -6.0)
	_cam.look_at(look, Vector3.UP)
	_cam.fov = lerpf(_cam.fov, 75.0 + (_speed - SPD_DEF) * 0.32, 2.5 * delta)
	_cam.rotation_degrees.z = lerpf(_cam.rotation_degrees.z, -_inp_x * 1.4, 4.0 * delta)

func _setup_lights():
	# Warm golden side-light — dusk sun low on horizon, NO shadow
	var sun = DirectionalLight3D.new()
	sun.light_color      = Color(1.00, 0.80, 0.45)
	sun.light_energy     = 1.80
	sun.rotation_degrees = Vector3(-22, 40, 0)
	sun.shadow_enabled   = false
	add_child(sun)

	# Soft cool fill from above (sky bounce)
	var fill = DirectionalLight3D.new()
	fill.light_color      = Color(0.50, 0.65, 0.95)
	fill.light_energy     = 0.80
	fill.rotation_degrees = Vector3(-75, -140, 0)
	fill.shadow_enabled   = false
	add_child(fill)

	# Warm back-rim (opposite horizon glow)
	var rim = DirectionalLight3D.new()
	rim.light_color      = Color(1.00, 0.50, 0.15)
	rim.light_energy     = 0.40
	rim.rotation_degrees = Vector3(-10, -140, 0)
	rim.shadow_enabled   = false
	add_child(rim)

func _build_clouds():
	# Spawn 10 cloud layers at different altitudes  dark grey, night sky feel
	for i in range(10):
		var cw  = randf_range(18.0, 70.0)
		var ch  = randf_range(2.5,  8.0)
		var cd  = randf_range(10.0, 35.0)
		var cx  = randf_range(-90.0, 90.0)
		var cy  = randf_range(28.0,  68.0)
		var cz  = randf_range(-260.0, -60.0)
		var col = Color(randf_range(0.18,0.30), randf_range(0.17,0.28), randf_range(0.22,0.38))
		var cloud = _box(Vector3(cw, ch, cd), col, 0.0, Color.BLACK, 0, 1.0)
		cloud.position = Vector3(cx, cy, cz)
		add_child(cloud)
		_clouds.append({
			node    = cloud,
			speed_x = randf_range(-1.2, 1.2),
			speed_z = randf_range(-0.4, 0.4),
			orig_x  = cx,
			orig_z  = cz
		})

func _update_clouds(delta: float):
	for c in _clouds:
		if not is_instance_valid(c.node): continue
		c.node.position.x += c.speed_x * delta
		c.node.position.z += c.speed_z * delta
		# Wrap around when they drift too far
		if abs(c.node.position.x - c.orig_x) > 55.0:
			c.speed_x = -c.speed_x
		if abs(c.node.position.z - c.orig_z) > 40.0:
			c.speed_z = -c.speed_z

# -----------------------------------------------------------------------------
#  Road tiles  (buildings are CHILDREN of tiles  auto-freed when tile is freed)
# -----------------------------------------------------------------------------
func _init_tiles():
	for i in range(N_TILES):
		_spawn_tile(SPAWN_Z + i * TILE_LEN)

func _spawn_tile(z: float):
	var tile = Node3D.new()
	var d = _world_dist - z
	tile.position.z = z
	tile.position.x = _curve_x(d)
	tile.rotation.y = atan(_curve_slope(d))
	add_child(tile)

	# Asphalt road — medium grey, dusk lighting
	_ti(tile, _box(Vector3(ROAD_W, 0.25, TILE_LEN), Color(0.26,0.26,0.28), 0.05, Color.BLACK, 0, 0.88))

	# Wide grass / ground extending 60 m on each side — fills the gaps behind buildings
	for sx in [-(ROAD_W*0.5 + 30.0), ROAD_W*0.5 + 30.0]:
		_ti(tile, _box(Vector3(60, 0.22, TILE_LEN), Color(0.18,0.44,0.09), 0.0, Color.BLACK, 0, 0.92), Vector3(sx, -0.02, 0))
	# Inner kerb strip
	for sx in [-(ROAD_W*0.5 + 1.0), ROAD_W*0.5 + 1.0]:
		_ti(tile, _box(Vector3(1.4, 0.18, TILE_LEN), Color(0.62,0.60,0.58), 0.04, Color.BLACK, 0, 0.90), Vector3(sx, 0.09, 0))

	# Bright white road edge lines
	for kx in [-(ROAD_W*0.5 - 0.08), ROAD_W*0.5 - 0.08]:
		_ti(tile, _box(Vector3(0.24, 0.06, TILE_LEN), Color(0.92,0.90,0.88), 0.0, Color.BLACK, 0, 0.75), Vector3(kx, 0.16, 0))

	# Concrete crash barriers with orange-red reflective top stripe
	for bx in [-(ROAD_W*0.5 + 0.7), ROAD_W*0.5 + 0.7]:
		_ti(tile, _box(Vector3(0.65, 0.60, TILE_LEN), Color(0.58,0.58,0.60), 0.08, Color.BLACK, 0, 0.82), Vector3(bx, 0.30, 0))
		_ti(tile, _box(Vector3(0.65, 0.10, TILE_LEN), Color(0.88,0.24,0.10), 0.0, Color.BLACK, 0, 0.60), Vector3(bx, 0.63, 0))

	# White dashed lane dividers
	var div_xs = [LANE_X[0]+(LANE_X[1]-LANE_X[0])*0.5,
				  LANE_X[1]+(LANE_X[2]-LANE_X[1])*0.5,
				  LANE_X[2]+(LANE_X[3]-LANE_X[2])*0.5]
	for dx in div_xs:
		var nd = 6
		var dl = TILE_LEN / nd * 0.50
		for i in range(nd):
			var dz = -TILE_LEN*0.5 + i * TILE_LEN/nd + dl*0.5
			_ti(tile, _box(Vector3(0.14, 0.06, dl), Color(0.90,0.88,0.86), 0.0, Color.BLACK, 0, 0.78),
				Vector3(dx, 0.16, dz))

	# Roadside scenery — NO buildings, just lamps and signs
	_add_scenery(tile)
	_tiles.append(tile)

static func _ti(tile: Node3D, mesh: MeshInstance3D, pos: Vector3 = Vector3.ZERO):
	mesh.position = pos; tile.add_child(mesh)

func _add_scenery(tile: Node3D):
	for side in [-1, 1]:
		# Street lamp — every tile
		var lx = float(side) * (ROAD_W * 0.5 + 1.6)
		var lz = randf_range(-TILE_LEN * 0.30, TILE_LEN * 0.30)
		_add_street_lamp(tile, lx, lz)

		# Buildings (0-1 per side — fewer, since each one is a lot of geometry)
		for _nb in range(randi_range(0, 1)):
			_make_building(tile, side)

		# Trees placed BEYOND the building zone (buildings max ~road+22m)
		# so trees never overlap buildings
		var n_trees = randi_range(1, 2)
		for _nt in range(n_trees):
			# Zone A: just outside road kerb (between kerb and nearest building face: road+2 to road+10)
			# Zone B: far beyond buildings (road+24 to road+42)
			var zone = randi() % 2
			var tx_dist = randf_range(2.5, 9.0) if zone == 0 else randf_range(24.0, 42.0)
			var tx = float(side) * (ROAD_W * 0.5 + tx_dist)
			var tz = randf_range(-TILE_LEN * 0.48, TILE_LEN * 0.48)
			_make_tree(tile, tx, tz)

		# Bushes near road kerb (always in zone A — never inside buildings)
		for _ns in range(randi_range(1, 2)):
			var bx2 = float(side) * (ROAD_W * 0.5 + randf_range(1.8, 8.0))
			var bz2 = randf_range(-TILE_LEN * 0.45, TILE_LEN * 0.45)
			_add_bush(tile, bx2, bz2)

		# Road sign (40% chance)
		if randf() > 0.60:
			var sx = float(side) * (ROAD_W * 0.5 + 2.0)
			var sz = randf_range(-TILE_LEN * 0.38, TILE_LEN * 0.38)
			var post = _box(Vector3(0.12, 4.5, 0.12), Color(0.45,0.45,0.48), 0.55, Color.BLACK, 0, 0.40)
			post.position = Vector3(sx, 2.25, sz); tile.add_child(post)
			var sign_cols = [Color(0.10,0.42,0.14), Color(0.06,0.24,0.60), Color(0.60,0.08,0.08)]
			var scol = sign_cols[randi() % 3]
			var sign_m = _box(Vector3(2.4, 0.95, 0.16), scol, 0.08, Color.BLACK, 0, 0.62)
			sign_m.position = Vector3(sx, 4.55, sz); tile.add_child(sign_m)
			var txt = _box(Vector3(2.0, 0.30, 0.18), Color(0.94,0.94,0.94), 0.0, Color.BLACK, 0, 0.68)
			txt.position = Vector3(sx, 4.55, sz); tile.add_child(txt)

		# Concrete kerb / pavement strip along road edge
		var kx = float(side) * (ROAD_W * 0.5 + 1.0)
		var kerb = _box(Vector3(1.20, 0.18, TILE_LEN), Color(0.62,0.60,0.58), 0.04, Color.BLACK, 0, 0.90)
		kerb.position = Vector3(kx, 0.09, 0.0); tile.add_child(kerb)

# Simple two-sphere bush / shrub (kept cheap — many of these exist per tile)
func _add_bush(tile: Node3D, tx: float, tz: float):
	var r = randf_range(0.55, 1.10)
	var g0 = Color(0.08, 0.28, 0.05)
	var g2 = Color(0.16, 0.46, 0.09)
	var b0 = _sphere(r, g0, 0.0, 0.96)
	b0.position = Vector3(tx, r * 0.55, tz); tile.add_child(b0)
	var bt = _sphere(r * 0.60, g2, 0.0, 0.97)
	bt.position = Vector3(tx, r * 1.10, tz); tile.add_child(bt)

func _make_building(tile: Node3D, side: int):
	# Facade runs ALONG Z (parallel to road)
	# Depth runs ALONG X (away from road into the block)
	# Windows are on the road-facing X face — always visible from camera
	var facade  = randf_range(14.0, 30.0)   # Z width (parallel to road)
	var bdepth  = randf_range(8.0,  18.0)   # X depth (into block)
	var bh      = randf_range(18.0, 68.0)   # height
	var gap     = randf_range(1.5,  4.5)    # gap: road edge to building face

	# Road-facing front face X position
	var front_x  = float(side) * (ROAD_W * 0.5 + gap)
	var center_x = front_x + float(side) * bdepth * 0.5
	var center_z = randf_range(-TILE_LEN * 0.45, TILE_LEN * 0.45)

	match randi() % 4:
		0: _bld_glass_tower   (tile, side, front_x, center_x, center_z, facade, bdepth, bh)
		1: _bld_stepped_tower (tile, side, front_x, center_x, center_z, facade, bdepth, bh)
		2: _bld_office_block  (tile, side, front_x, center_x, center_z, facade, bdepth, bh)
		3: _bld_apartment     (tile, side, front_x, center_x, center_z, facade, bdepth, bh)

# Shared: place an emissive window grid on the road-facing X face
# NOTE: one mesh per window cell (no separate frame+glass), and rows/columns are
# spaced wider than the original grid — window count is the single biggest lever
# on frame rate since it's repeated for every building on every tile.
func _road_windows(tile: Node3D, side: int, front_x: float, center_z: float,
				   facade: float, bh: float, floor_h: float, wc: Color):
	var n_cols  = max(2, int(facade / 6.0))
	var n_rows  = max(1, int(bh    / floor_h) - 1)
	var col_w   = facade / float(n_cols)
	var off_x   = -float(side) * 0.06   # window sits proud of the face
	var row = 0
	while row < n_rows:
		for col in range(n_cols):
			var wz = center_z - facade * 0.5 + (float(col) + 0.5) * col_w
			var wy = float(row) * floor_h + floor_h * 0.6
			if randf() > 0.38:   # 62 % lit — not too many
				var win = _box(Vector3(0.11, floor_h * 0.60, col_w * 0.62),
							   wc * 0.55, 0.0, wc, 1.4, 0.05)
				win.position = Vector3(front_x + off_x, wy, wz)
				tile.add_child(win)
			else:                # dark glass / blind
				var dark = _box(Vector3(0.11, floor_h * 0.60, col_w * 0.66),
								Color(0.06, 0.10, 0.18), 0.22, Color.BLACK, 0, 0.28)
				dark.position = Vector3(front_x + off_x, wy, wz)
				tile.add_child(dark)
		row += 2

# Shared: add floor-band spandrels across the front facade
func _facade_bands(tile: Node3D, front_x: float, center_z: float,
				   facade: float, bh: float, floor_h: float, col: Color):
	var bands = int(bh / floor_h)
	for b in range(bands + 1):
		var fy = float(b) * floor_h
		var band = _box(Vector3(0.22, 0.28, facade + 0.20), col, 0.18, Color.BLACK, 0, 0.72)
		band.position = Vector3(front_x, fy, center_z)
		tile.add_child(band)

# TYPE 0 ---- Glass curtain-wall skyscraper (50-92 m) -------------------------
func _bld_glass_tower(tile: Node3D, side: int, front_x: float, center_x: float,
					  center_z: float, facade: float, bdepth: float, bh: float):
	bh = clampf(bh, 50.0, 92.0)
	var glass = Color(randf_range(0.08, 0.18), randf_range(0.14, 0.30), randf_range(0.20, 0.44))
	var wc    = Color(0.55, 0.84, 1.00) if randf() > 0.5 else Color(0.64, 1.00, 0.75)

	# Core concrete body
	var body = _box(Vector3(bdepth, bh, facade), Color(0.07, 0.08, 0.12), 0.12, Color.BLACK, 0, 0.85)
	body.position = Vector3(center_x, bh * 0.5, center_z); tile.add_child(body)

	# Glass curtain panels on road face
	var floor_h = 3.4
	_road_windows(tile, side, front_x, center_z, facade, bh, floor_h, wc)

	# Horizontal spandrel bands every floor
	_facade_bands(tile, front_x, center_z, facade, bh, floor_h, glass.darkened(0.40))

	# Vertical corner mullions
	for fz in [-facade * 0.5 + 0.2, facade * 0.5 - 0.2]:
		var mul = _box(Vector3(0.35, bh + 0.4, 0.35), Color(0.14, 0.14, 0.18), 0.55, Color.BLACK, 0, 0.28)
		mul.position = Vector3(front_x, bh * 0.5, center_z + fz); tile.add_child(mul)

	# Setback penthouse
	var ph_w = facade * 0.52; var ph_d = bdepth * 0.50; var ph_h = 6.0
	var ph = _box(Vector3(ph_d, ph_h, ph_w), glass, 0.14, Color.BLACK, 0, 0.80)
	ph.position = Vector3(center_x, bh + ph_h * 0.5, center_z); tile.add_child(ph)

	# Parapet
	var para = _box(Vector3(bdepth + 0.4, 1.0, facade + 0.4), Color(0.09, 0.09, 0.13), 0.35, Color.BLACK, 0, 0.72)
	para.position = Vector3(center_x, bh + 0.5, center_z); tile.add_child(para)

	# Communication tower + blinking beacon
	var tower = _box(Vector3(0.24, randf_range(8.0, 16.0), 0.24), Color(0.38, 0.38, 0.43), 0.85, Color.BLACK, 0, 0.18)
	tower.position = Vector3(center_x, bh + ph_h + tower.mesh.size.y * 0.5, center_z); tile.add_child(tower)
	var beacon = _box(Vector3(0.36, 0.36, 0.36), Color(1.0, 0.06, 0.06), 0.0, Color(1.0, 0.08, 0.08), 12.0, 0.0)
	beacon.position = Vector3(center_x, bh + ph_h + 18.0, center_z); tile.add_child(beacon)

	# Roof glow
	var rl = OmniLight3D.new(); rl.light_color = wc; rl.light_energy = 0.8; rl.omni_range = 14.0
	rl.position = Vector3(center_x, bh + ph_h + 1.0, center_z); tile.add_child(rl)

# TYPE 1 ---- Stepped Art-Deco tower (35-70 m) --------------------------------
func _bld_stepped_tower(tile: Node3D, side: int, front_x: float, center_x: float,
						center_z: float, facade: float, bdepth: float, bh: float):
	bh = clampf(bh, 35.0, 70.0)
	var wall   = Color(randf_range(0.16, 0.28), randf_range(0.13, 0.23), randf_range(0.10, 0.20))
	var accent = Color(randf_range(0.55, 0.90), randf_range(0.45, 0.78), randf_range(0.08, 0.40))
	var floor_h = 3.2
	# 3 setback tiers — each tier is narrower than the previous
	var tier_data = [
		[1.00, 1.00, 0.40],
		[0.68, 0.65, 0.32],
		[0.42, 0.42, 0.28],
	]
	var base_y = 0.0
	for i in range(tier_data.size()):
		var tf  = facade  * tier_data[i][0]   # tier facade width
		var td  = bdepth  * tier_data[i][1]   # tier depth
		var th  = bh      * tier_data[i][2]   # tier height
		var tcx = center_x + float(side) * (bdepth - td) * 0.5   # tier shifts away from road
		# Offset front face inward for setback
		var tfx = tcx - float(side) * td * 0.5

		var body = _box(Vector3(td, th, tf), wall, 0.12, Color.BLACK, 0, 0.80)
		body.position = Vector3(tcx, base_y + th * 0.5, center_z); tile.add_child(body)

		# Corner pilasters on front face
		for fz in [-tf * 0.5 + 0.3, tf * 0.5 - 0.3]:
			var pil = _box(Vector3(0.52, th + 0.2, 0.52), wall.lightened(0.18), 0.15, Color.BLACK, 0, 0.72)
			pil.position = Vector3(tfx, base_y + th * 0.5, center_z + fz); tile.add_child(pil)

		# Cornice
		var corn = _box(Vector3(td + 0.55, 0.55, tf + 0.55), wall.lightened(0.25), 0.18, Color.BLACK, 0, 0.68)
		corn.position = Vector3(tcx, base_y + th, center_z); tile.add_child(corn)

		# Road-facing windows
		_road_windows(tile, side, tfx, center_z, tf, th, floor_h, Color(0.88, 0.80, 0.52))

		# Accent bands
		var n_b = max(1, int(th / (floor_h * 3)))
		for b in range(n_b):
			var by = base_y + float(b + 1) * th / float(n_b + 1)
			var band = _box(Vector3(td + 0.18, 0.28, tf + 0.18), accent * 0.5, 0.0, accent, 1.5, 0.08)
			band.position = Vector3(tcx, by, center_z); tile.add_child(band)

		base_y += th

	# Spire
	var spire_h = bh * 0.14
	var spire = _cylinder(0.18, spire_h, Color(0.42, 0.42, 0.48), 0.88, 0.12)
	spire.position = Vector3(center_x, base_y + spire_h * 0.5, center_z); tile.add_child(spire)
	var top = _sphere(0.30, accent, 0.0, 0.08)
	top.position = Vector3(center_x, base_y + spire_h, center_z); tile.add_child(top)
	var tl = OmniLight3D.new(); tl.light_color = accent; tl.light_energy = 1.2; tl.omni_range = 8.0
	tl.position = Vector3(center_x, base_y + spire_h + 0.4, center_z); tile.add_child(tl)

# TYPE 2 ---- Modern ribbon-glass office block (15-35 m) ----------------------
func _bld_office_block(tile: Node3D, side: int, front_x: float, center_x: float,
					   center_z: float, facade: float, bdepth: float, bh: float):
	bh = clampf(bh, 15.0, 35.0)
	var concrete = Color(randf_range(0.16, 0.26), randf_range(0.14, 0.24), randf_range(0.16, 0.28))
	var glass_c  = Color(randf_range(0.30, 0.60), randf_range(0.60, 0.92), randf_range(0.50, 0.92))
	var floor_h  = 4.0
	var n_floors = max(2, int(bh / floor_h))

	# Structural slab
	var slab = _box(Vector3(bdepth, bh, facade), concrete, 0.15, Color.BLACK, 0, 0.82)
	slab.position = Vector3(center_x, bh * 0.5, center_z); tile.add_child(slab)

	# Continuous glass ribbon per floor on road face (very wide, thin horizontal bands)
	for f in range(n_floors):
		var fy = float(f) * floor_h + floor_h * 0.55
		var ribbon = _box(Vector3(0.09, floor_h * 0.55, facade * 0.90),
						  glass_c * 0.45, 0.0, glass_c, 2.8, 0.02)
		ribbon.position = Vector3(front_x - float(side) * 0.05, fy, center_z)
		tile.add_child(ribbon)
		# Spandrel (dark strip between floors)
		var span = _box(Vector3(0.18, 0.28, facade + 0.15), concrete.darkened(0.14), 0.18, Color.BLACK, 0, 0.78)
		span.position = Vector3(front_x, float(f) * floor_h, center_z); tile.add_child(span)

	# Vertical structural columns on face
	var n_vcol = max(2, int(facade / 5.0))
	for vc in range(n_vcol + 1):
		var vcz = center_z - facade * 0.5 + float(vc) * facade / float(n_vcol)
		var col_m = _box(Vector3(0.32, bh, 0.32), concrete.lightened(0.14), 0.20, Color.BLACK, 0, 0.74)
		col_m.position = Vector3(front_x, bh * 0.5, vcz); tile.add_child(col_m)

	# Ground floor lobby — darker, taller glazing
	var lobby = _box(Vector3(0.09, floor_h * 0.90, facade * 0.82), glass_c * 0.35, 0.0, glass_c * 0.8, 2.0, 0.05)
	lobby.position = Vector3(front_x - float(side) * 0.05, floor_h * 0.45, center_z); tile.add_child(lobby)

	# Flat roof + mechanical room
	var roof = _box(Vector3(bdepth + 0.35, 0.60, facade + 0.35), concrete.darkened(0.10), 0.22, Color.BLACK, 0, 0.75)
	roof.position = Vector3(center_x, bh + 0.30, center_z); tile.add_child(roof)
	var mech = _box(Vector3(bdepth * 0.35, 3.2, facade * 0.30), Color(0.10, 0.10, 0.14), 0.28, Color.BLACK, 0, 0.80)
	mech.position = Vector3(center_x, bh + 2.0, center_z + facade * 0.18); tile.add_child(mech)
	# Roof glow
	var rl = OmniLight3D.new(); rl.light_color = glass_c; rl.light_energy = 0.5; rl.omni_range = 10.0
	rl.position = Vector3(front_x, bh + 1.5, center_z); tile.add_child(rl)

# TYPE 3 ---- Brick apartment block (20-45 m) ---------------------------------
func _bld_apartment(tile: Node3D, side: int, front_x: float, center_x: float,
					center_z: float, facade: float, bdepth: float, bh: float):
	bh = clampf(bh, 20.0, 45.0)
	var brick  = Color(randf_range(0.24, 0.42), randf_range(0.13, 0.24), randf_range(0.08, 0.18))
	var trim   = brick.lightened(0.32)
	var wc     = Color(0.92, 0.82, 0.54) if randf() > 0.5 else Color(0.68, 0.90, 1.0)
	var floor_h = 3.0
	var n_floors = max(2, int(bh / floor_h))

	# Main body
	var body = _box(Vector3(bdepth, bh, facade), brick, 0.05, Color.BLACK, 0, 0.93)
	body.position = Vector3(center_x, bh * 0.5, center_z); tile.add_child(body)

	# Horizontal mortar bands every 2 floors (visible on front face)
	for f in range(n_floors / 2):
		var my = float(f) * floor_h * 2 + floor_h
		var band = _box(Vector3(0.14, 0.14, facade + 0.10), brick.lightened(0.28), 0.04, Color.BLACK, 0, 0.96)
		band.position = Vector3(front_x, my, center_z); tile.add_child(band)

	# Corner quoins — alternating light blocks at corners
	for fz in [-facade * 0.5, facade * 0.5]:
		for f in range(n_floors):
			if f % 2 == 0:
				var q = _box(Vector3(0.15, 0.42, 0.60), trim, 0.04, Color.BLACK, 0, 0.90)
				q.position = Vector3(front_x, float(f) * floor_h + floor_h * 0.5, center_z + fz)
				tile.add_child(q)

	# Road-facing windows with sill band per floor
	_road_windows(tile, side, front_x, center_z, facade, bh, floor_h, wc)
	for f in range(n_floors):
		var sill = _box(Vector3(0.14, 0.16, facade * 0.92), trim, 0.04, Color.BLACK, 0, 0.90)
		sill.position = Vector3(front_x, float(f) * floor_h + floor_h * 0.28, center_z)
		tile.add_child(sill)

	# Decorative lintel above ground floor
	var lin = _box(Vector3(0.20, 0.40, facade + 0.22), trim, 0.04, Color.BLACK, 0, 0.88)
	lin.position = Vector3(front_x, floor_h + 0.10, center_z); tile.add_child(lin)

	# Balconies every 3 floors
	for f in range(2, n_floors):
		if f % 3 == 0:
			var bal_y = float(f) * floor_h
			var bal = _box(Vector3(0.15, facade * 0.86, 1.30), trim, 0.04, Color.BLACK, 0, 0.92)
			bal.rotation_degrees = Vector3(0.0, 0.0, 90.0)
			bal.position = Vector3(front_x - float(side) * 0.82, bal_y, center_z); tile.add_child(bal)
			var rail = _box(Vector3(0.08, facade * 0.82, 0.06), trim.lightened(0.18), 0.12, Color.BLACK, 0, 0.80)
			rail.rotation_degrees = Vector3(0.0, 0.0, 90.0)
			rail.position = Vector3(front_x - float(side) * 1.60, bal_y + 0.92, center_z); tile.add_child(rail)

	# Parapet + chimneys
	var para = _box(Vector3(bdepth + 0.32, 0.85, facade + 0.32), brick.lightened(0.14), 0.04, Color.BLACK, 0, 0.92)
	para.position = Vector3(center_x, bh + 0.42, center_z); tile.add_child(para)
	for _ch in range(randi_range(1, 3)):
		var chz = center_z + randf_range(-facade * 0.35, facade * 0.35)
		var chi = _cylinder(0.32, randf_range(1.5, 3.2), Color(0.22, 0.13, 0.08), 0.04, 0.96)
		chi.position = Vector3(center_x + randf_range(-bdepth * 0.28, bdepth * 0.28), bh + 2.0, chz)
		tile.add_child(chi)
func _add_street_lamp(tile: Node3D, x: float, z: float):
	# Post
	var post = _box(Vector3(0.14, 5.5, 0.14), Color(0.35,0.35,0.40), 0.75, Color.BLACK, 0, 0.25)
	post.position = Vector3(x, 2.75, z); tile.add_child(post)
	# Horizontal arm toward road
	var arm_dir = -1.0 if x > 0 else 1.0
	var arm = _box(Vector3(1.8, 0.10, 0.10), Color(0.35,0.35,0.40), 0.75, Color.BLACK, 0, 0.25)
	arm.position = Vector3(x + arm_dir * 0.9, 5.5, z); tile.add_child(arm)
	# Lamp head (emissive warm orange)
	var bulb = _box(Vector3(0.55, 0.28, 0.55), Color(1.0,0.82,0.50), 0.0, Color(1.0,0.82,0.50), 10.0, 0.05)
	bulb.position = Vector3(x + arm_dir * 1.8, 5.35, z); tile.add_child(bulb)
	# Point light — brighter for dusk visibility
	var light = OmniLight3D.new()
	light.light_color    = Color(1.00, 0.85, 0.55)
	light.light_energy   = 4.5
	light.omni_range     = 26.0
	light.shadow_enabled = false
	light.position = Vector3(x + arm_dir * 1.8, 5.35, z)
	tile.add_child(light)

# Detailed multi-sphere tree matching the reference image (full, round, bushy)
func _make_tree(tile: Node3D, tx: float, tz: float) -> Node3D:
	# All parts live inside a single root so we can sway the whole tree.
	# Kept deliberately cheap (~6 meshes) — many trees exist per tile, and
	# this was previously ~27 meshes each, which was the single biggest
	# framerate cost in the whole scene.
	var root = Node3D.new()
	root.position = Vector3(tx, 0.0, tz)
	tile.add_child(root)

	var trunk_h = randf_range(2.4, 4.2)
	var trunk_r = randf_range(0.20, 0.32)
	var cr      = randf_range(2.0, 3.6)
	var cy      = trunk_h + cr * 0.72

	var trunk = _cylinder(trunk_r, trunk_h, Color(0.29,0.18,0.06), 0.0, 0.95)
	trunk.position = Vector3(0, trunk_h*0.5, 0); root.add_child(trunk)

	# Foliage palette
	var g1 = Color(0.08, 0.26, 0.05)
	var g2 = Color(0.11, 0.34, 0.07)
	var g4 = Color(0.17, 0.50, 0.11)

	var core = _sphere(cr, g1, 0.0, 0.94)
	core.position = Vector3(0, cy, 0); root.add_child(core)

	for off in [Vector3(cr*0.55,cr*0.10,0), Vector3(-cr*0.55,cr*0.10,0),
				Vector3(0,cr*0.10,cr*0.55), Vector3(0,cr*0.10,-cr*0.55)]:
		var mc = _sphere(randf_range(cr*0.48, cr*0.62), g2, 0.0, 0.95)
		mc.position = Vector3(0, cy, 0) + off; root.add_child(mc)

	var top1 = _sphere(randf_range(cr*0.42, cr*0.56), g4, 0.0, 0.97)
	top1.position = Vector3(cr*0.12, cy+cr*0.65, cr*0.08); root.add_child(top1)

	# Gentle wind sway animation on the whole tree
	var sway   = randf_range(0.5, 1.4)
	var speed  = randf_range(1.8, 4.2)
	var phase  = randf_range(0.0, 3.14)   # offset so trees don't sway in sync
	var tw = root.create_tween()
	tw.set_loops(); tw.set_trans(Tween.TRANS_SINE); tw.set_ease(Tween.EASE_IN_OUT)
	tw.tween_interval(phase)
	tw.tween_property(root, "rotation_degrees:z",  sway, speed)
	tw.tween_property(root, "rotation_degrees:z", -sway, speed)

	return root

# _add_buildings kept as alias
func _add_buildings(tile: Node3D):
	_add_scenery(tile)

func _move_world(delta: float):
	var dz = _speed * delta
	_world_dist += dz
	for i in range(_tiles.size() - 1, -1, -1):
		_tiles[i].position.z += dz
		if _tiles[i].position.z > DEAD_Z:
			_tiles[i].queue_free(); _tiles.remove_at(i)
			var front = _front_z()
			_spawn_tile(front - TILE_LEN)
	for i in range(_obs.size() - 1, -1, -1):
		_obs[i].node.position.z += dz * _obs[i].smult
		if _obs[i].node.position.z > DEAD_Z + 5:
			_obs[i].node.queue_free(); _obs.remove_at(i)
	for i in range(_coins3.size() - 1, -1, -1):
		_coins3[i].node.position.z += dz
		if _coins3[i].node.position.z > DEAD_Z + 5:
			_coins3[i].node.queue_free(); _coins3.remove_at(i)

func _front_z() -> float:
	var mz = 9999.0
	for t in _tiles: mz = minf(mz, t.position.z)
	return mz

# -----------------------------------------------------------------------------
#  Player car  (detailed realistic design)
# -----------------------------------------------------------------------------
func _build_player():
	if is_instance_valid(_player): _player.queue_free()
	var cd = _get_car_def()
	_player = _make_car(cd.body, cd.accent, true, cd.id)
	_player.position = Vector3(_player_offset + _curve_x(_world_dist), CAR_Y, 0)
	add_child(_player)
	_build_engine_sound()

func _build_engine_sound():
	if is_instance_valid(_engine_player): _engine_player.queue_free()
	_engine_player = AudioStreamPlayer3D.new()
	_engine_player.stream   = _gen_engine_wav()
	_engine_player.volume_db = -9.0
	_engine_player.unit_size = 22.0
	_engine_player.max_db    = -3.0
	_engine_player.autoplay  = true
	_player.add_child(_engine_player)

# Generates a looping engine-idle WAV using PCM (no audio files needed).
# Uses 1764 samples at 22050 Hz = exactly 2 cycles of 25 Hz (all harmonics loop cleanly).
static func _gen_engine_wav() -> AudioStreamWAV:
	var sr = 22050
	var n  = 1764          # 1764/22050 = 0.08 s; 25 Hz  0.08 s = 2 cycles  clean loop
	var wav = AudioStreamWAV.new()
	wav.format     = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo     = false
	wav.mix_rate   = sr
	wav.loop_mode  = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end   = n - 1
	var data = PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var t = float(i) / sr
		var s = 0.0
		s += sin(TAU * 50.0  * t) * 0.28   # fundamental (V8 firing = ~50 Hz at idle)
		s += sin(TAU * 100.0 * t) * 0.22   # 2nd harmonic (strong in engines)
		s += sin(TAU * 150.0 * t) * 0.15   # 3rd harmonic
		s += sin(TAU * 200.0 * t) * 0.10   # 4th harmonic
		s += sin(TAU * 250.0 * t + 0.7) * 0.06  # 5th harmonic (growl)
		s += sin(TAU * 25.0  * t) * 0.12   # sub-harmonic (body rumble)
		var pulse = sin(TAU * 25.0 * t) * 0.18 + 0.82   # engine-stroke pulse
		s *= pulse * 0.28
		var v = clamp(int(s * 32767), -32767, 32767)
		data[i * 2]     = v & 0xFF
		data[i * 2 + 1] = (v >> 8) & 0xFF
	wav.data = data
	return wav

func _get_car_def() -> Dictionary:
	var sel = SettingsManager.race_selected if SettingsManager else "blue"
	for d in SettingsManager.CAR_DEFS:
		if d.id == sel: return d
	return SettingsManager.CAR_DEFS[0]
# Dispatches to a distinct body-shape builder per car model — cars differ in
# actual silhouette (length/height/wedge/flare), not just paint colour.
func _make_car(bc: Color, ac: Color, is_player: bool, model: String = "blue") -> Node3D:
	match model:
		"green":  return _make_car_hatch(bc, ac, is_player)
		"red":    return _make_car_muscle(bc, ac, is_player)
		"purple": return _make_car_super(bc, ac, is_player)
		"gold":   return _make_car_suv(bc, ac, is_player)
		_:        return _make_car_sport(bc, ac, is_player)

# - CORVETTE C8 Z06 - Curved-mesh body (CylinderMesh+SphereMesh) - smaller scale -
# --- CORVETTE C8 Z06 - Correct flat sports-car proportions -----------------
func _make_car_sport(bc: Color, ac: Color, is_player: bool) -> Node3D:
	var c = Node3D.new()
	c.scale = Vector3(0.80, 0.80, 0.80)

	# PBR colours - shiny automotive paint
	var dark = bc.darkened(0.40)
	var mid  = bc.darkened(0.16)
	var lite = bc.lightened(0.20)
	# Body material helper
	var bm = StandardMaterial3D.new()
	bm.albedo_color = bc; bm.metallic = 0.85; bm.roughness = 0.18

	# PROPORTIONS (local Y):  world_y = local_y*0.80 + 0.44
	# Ground:0m  Wheel:0.44m  Belly:0.54m  Beltline:0.82m  Roof:1.10m  Wing:1.50m
	# local:      0           0.13          0.47             0.82        1.34

	# 1 -- MAIN BODY ELLIPSE (CylinderMesh, axis along Z = car length)
	# Very flat scale: gives 2.08m wide x 0.60m tall body cross-section
	var lo = MeshInstance3D.new(); var lo_cm = CylinderMesh.new()
	lo_cm.top_radius = 0.56; lo_cm.bottom_radius = 0.56; lo_cm.height = 3.80
	lo_cm.radial_segments = 32; lo_cm.rings = 1
	lo.mesh = lo_cm; lo.scale = Vector3(1.86, 0.54, 1.0)
	lo.position = Vector3(0, 0.20, 0); lo.rotation_degrees.x = 90
	lo.set_surface_override_material(0, bm); c.add_child(lo)

	# 2 -- UPPER BODY SHOULDER (narrow ellipse, smooth transition to cabin)
	var ub = MeshInstance3D.new(); var ub_cm = CylinderMesh.new()
	ub_cm.top_radius = 0.46; ub_cm.bottom_radius = 0.46; ub_cm.height = 2.85
	ub_cm.radial_segments = 26; ub_cm.rings = 1
	ub.mesh = ub_cm; ub.scale = Vector3(1.55, 0.50, 1.0)
	var ubm = bm.duplicate() as StandardMaterial3D
	ubm.albedo_color = mid; ub.set_surface_override_material(0, ubm)
	ub.position = Vector3(0, 0.52, -0.15); ub.rotation_degrees.x = 90; c.add_child(ub)

	# 3 -- CABIN (much smaller, pushed far forward for mid-engine look)
	var cab = MeshInstance3D.new(); var cab_cm = CylinderMesh.new()
	cab_cm.top_radius = 0.40; cab_cm.bottom_radius = 0.40; cab_cm.height = 1.38
	cab_cm.radial_segments = 20; cab_cm.rings = 1
	cab.mesh = cab_cm; cab.scale = Vector3(1.35, 0.42, 1.0)
	var cabm = bm.duplicate() as StandardMaterial3D
	cabm.albedo_color = lite; cab.set_surface_override_material(0, cabm)
	cab.position = Vector3(0, 0.66, 0.48); cab.rotation_degrees.x = 90; c.add_child(cab)

	# 4 -- ROOF DOME (SphereMesh - smooth, not a flat box)
	var roof = _sphere(0.48, lite.lightened(0.10), 0.80, 0.18)
	roof.scale = Vector3(1.28, 0.26, 1.14)
	roof.position = Vector3(0, 0.85, 0.48); c.add_child(roof)

	# 5 -- REAR FENDER BULGES (stretched spheres - the wide Corvette haunches)
	for rx in [-1.0, 1.0]:
		var fh = _sphere(0.52, mid, 0.82, 0.22)
		fh.scale = Vector3(0.48, 0.86, 1.85)
		fh.position = Vector3(rx * 1.04, 0.25, 1.15); c.add_child(fh)
		# Fender highlight crease
		var fl = _sphere(0.44, lite.lightened(0.18), 0.88, 0.15)
		fl.scale = Vector3(0.10, 0.68, 1.80)
		fl.position = Vector3(rx * 1.13, 0.28, 1.13); c.add_child(fl)

	# 6 -- FRONT FENDER BULGES
	for rx in [-0.88, 0.88]:
		var ffh = _sphere(0.46, mid, 0.80, 0.24)
		ffh.scale = Vector3(0.44, 0.78, 1.28)
		ffh.position = Vector3(rx, 0.22, -1.38); c.add_child(ffh)

	# 7 -- FLOOR / UNDERBODY
	_cm(c, _box(Vector3(2.40, 0.08, 4.42), Color(0.06,0.06,0.08), 0.3), Vector3(0, 0.06, 0))
	# Front splitter (very low, ground-scraping)
	_cm(c, _box(Vector3(2.15, 0.05, 0.38), Color(0.06,0.06,0.07), 0.4), Vector3(0, 0.08, -2.32))

	# 8 -- HOOD (flat, short - mid-engine car)
	_cm(c, _box(Vector3(1.80, 0.07, 1.05), mid, 0.70), Vector3(0, 0.46, -1.84))
	var hd = _sphere(0.40, lite, 0.82, 0.18)
	hd.scale = Vector3(0.50, 0.12, 1.04); hd.position = Vector3(0, 0.51, -1.84); c.add_child(hd)
	for hx in [-0.46, 0.46]:
		_cm(c, _box(Vector3(0.38, 0.10, 0.42), Color(0.06,0.06,0.08), 0.1), Vector3(hx, 0.50, -1.83))

	# 9 -- ENGINE COVER (long rear deck, very flat - the Corvette signature)
	_cm(c, _box(Vector3(1.84, 0.07, 1.18), mid, 0.65), Vector3(0, 0.52, 1.45))

	# 10 -- GLASS (very dark tinted, raked sharply)
	var gm = StandardMaterial3D.new()
	gm.albedo_color = Color(0.08,0.14,0.22,0.40); gm.metallic=0.15; gm.roughness=0.04
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; gm.cull_mode = BaseMaterial3D.CULL_DISABLED
	var fw = MeshInstance3D.new(); var fwm = BoxMesh.new()
	fwm.size = Vector3(1.42, 0.50, 0.09); fw.mesh = fwm; fw.set_surface_override_material(0, gm)
	fw.position = Vector3(0, 0.75, 1.38); fw.rotation_degrees.x = -62.0; c.add_child(fw)
	var rwm = BoxMesh.new(); rwm.size = Vector3(1.22, 0.36, 0.08)
	var rwi = MeshInstance3D.new(); rwi.mesh = rwm; rwi.set_surface_override_material(0, gm)
	rwi.position = Vector3(0, 0.72, -0.26); rwi.rotation_degrees.x = 64.0; c.add_child(rwi)
	for qx in [-0.90, 0.90]:
		var qgm = gm.duplicate() as StandardMaterial3D
		var qwm = BoxMesh.new(); qwm.size = Vector3(0.06, 0.28, 0.58)
		var qwi = MeshInstance3D.new(); qwi.mesh = qwm; qwi.set_surface_override_material(0, qgm)
		qwi.position = Vector3(qx, 0.76, 0.78); c.add_child(qwi)
		var qwr = qwi.duplicate() as MeshInstance3D; qwr.position = Vector3(qx, 0.74, -0.24); c.add_child(qwr)

	# 11 -- PILLARS (A/B/C)
	for px in [-0.90, 0.90]:
		_cm(c, _box(Vector3(0.10, 0.48, 0.12), dark, 0.3), Vector3(px, 0.62, 1.36))
		_cm(c, _box(Vector3(0.11, 0.46, 0.13), dark, 0.3), Vector3(px, 0.62, 0.18))
		_cm(c, _box(Vector3(0.10, 0.42, 0.12), dark, 0.3), Vector3(px, 0.62, -0.26))

	# 12 -- FRONT FASCIA
	_cm(c, _box(Vector3(1.88, 0.55, 0.11), Color(0.08,0.08,0.11), 0.3), Vector3(0, 0.26, -2.23))
	_cm(c, _box(Vector3(1.20, 0.32, 0.09), Color(0.04,0.04,0.05)), Vector3(0, 0.18, -2.25))
	for gb in range(5):
		_cm(c, _box(Vector3(1.12, 0.04, 0.08), Color(0.22,0.22,0.26), 0.55),
			Vector3(0, 0.10 + gb*0.058, -2.26))
	for fx in [-0.72, 0.72]:
		_cm(c, _box(Vector3(0.36, 0.26, 0.09), Color(0.05,0.05,0.07)), Vector3(fx, 0.22, -2.23))
	_cm(c, _box(Vector3(1.76, 0.22, 0.10), mid, 0.70), Vector3(0, 0.45, -2.23))
	_cm(c, _box(Vector3(0.18, 0.16, 0.06), Color(0.82,0.74,0.14), 0.94, Color(0.95,0.88,0.22), 2.2),
		Vector3(0, 0.35, -2.24))

	# 13 -- HEADLIGHTS (LED DRL blade style)
	for side in [-1, 1]:
		var hx = side * 0.82
		_cm(c, _box(Vector3(0.54, 0.20, 0.10), Color(0.06,0.06,0.09)), Vector3(hx, 0.40, -2.22))
		_cm(c, _box(Vector3(0.46, 0.05, 0.09), Color(0,0,0), 0, Color(1.0,0.98,0.92), 7.0),
			Vector3(hx, 0.50, -2.22))
		_cm(c, _box(Vector3(0.38, 0.14, 0.08), Color(0.84,0.90,0.95), 0.20),
			Vector3(hx, 0.39, -2.22))
		if is_player:
			var hl = OmniLight3D.new()
			hl.light_color = Color(1.0,0.97,0.90); hl.light_energy = 2.5; hl.omni_range = 14.0
			hl.position = Vector3(hx, 0.40, -3.4); c.add_child(hl)

	# 14 -- REAR FASCIA (most visible from camera)
	_cm(c, _box(Vector3(2.36, 0.50, 0.13), mid.darkened(0.12), 0.65), Vector3(0, 0.48, 2.24))
	_cm(c, _box(Vector3(2.38, 0.44, 0.13), Color(0.07,0.07,0.10), 0.28), Vector3(0, 0.20, 2.24))

	# 15 -- TAILLIGHTS (C8 Z06 - full-width LED bar + boomerang clusters)
	# Central connecting bar
	_cm(c, _box(Vector3(2.40, 0.08, 0.10), Color(0,0,0), 0, Color(0.97,0.04,0.04), 8.0),
		Vector3(0, 0.72, 2.23))
	if is_player:
		var tl = OmniLight3D.new()
		tl.light_color = Color(1.0,0.04,0.04); tl.light_energy = 1.2; tl.omni_range = 4.0
		tl.position = Vector3(0, 0.72, 2.35); c.add_child(tl)
	for side in [-1, 1]:
		var tx = side * 0.94
		_cm(c, _box(Vector3(0.54, 0.34, 0.12), Color(0.05,0.01,0.01), 0.1), Vector3(tx, 0.53, 2.22))
		# Top LED blade
		_cm(c, _box(Vector3(0.46, 0.07, 0.10), Color(0,0,0), 0, Color(0.93,0.04,0.04), 6.0),
			Vector3(tx, 0.69, 2.23))
		# Diagonal boomerang A
		_cm(c, _box(Vector3(0.10, 0.28, 0.10), Color(0,0,0), 0, Color(0.90,0.04,0.04), 5.0),
			Vector3(tx - side*0.18, 0.58, 2.23))
		# Diagonal boomerang B
		_cm(c, _box(Vector3(0.10, 0.20, 0.10), Color(0,0,0), 0, Color(0.88,0.04,0.04), 4.5),
			Vector3(tx - side*0.08, 0.48, 2.23))
		# Bottom strip
		_cm(c, _box(Vector3(0.46, 0.06, 0.10), Color(0,0,0), 0, Color(0.86,0.04,0.04), 4.0),
			Vector3(tx, 0.37, 2.23))
		# Side wrap onto quarter
		_cm(c, _box(Vector3(0.11, 0.32, 0.34), Color(0,0,0), 0, Color(0.88,0.04,0.04), 3.5),
			Vector3(side*1.28, 0.52, 2.12))
		# Reverse + amber
		_cm(c, _box(Vector3(0.18, 0.10, 0.10), Color(0,0,0), 0, Color(0.94,0.94,0.96), 3.5),
			Vector3(tx, 0.26, 2.23))
		_cm(c, _box(Vector3(0.16, 0.08, 0.10), Color(0,0,0), 0, Color(0.96,0.66,0.04), 2.8),
			Vector3(tx, 0.16, 2.23))

	# 16 -- LICENSE PLATE
	_cm(c, _box(Vector3(0.42, 0.20, 0.06), Color(0.06,0.06,0.08)), Vector3(0, 0.34, 2.26))
	_cm(c, _box(Vector3(0.36, 0.14, 0.05), Color(0.88,0.88,0.90)), Vector3(0, 0.34, 2.28))

	# 17 -- REAR DIFFUSER (carbon, simplified — fins merged into ridge texture look)
	_cm(c, _box(Vector3(1.88, 0.26, 0.44), Color(0.06,0.06,0.07), 0.3), Vector3(0, 0.10, 2.27))
	_cm(c, _box(Vector3(1.82, 0.04, 0.40), Color(0.44,0.44,0.48), 0.88), Vector3(0, 0.03, 2.26))

	# 18 -- DUAL EXHAUST (chrome rings, centred)
	_cm(c, _box(Vector3(1.02, 0.24, 0.12), Color(0.06,0.06,0.08), 0.2), Vector3(0, 0.17, 2.32))
	for ex in [-0.20, 0.20]:
		_cm(c, _cylinder(0.090, 0.26, Color(0.76,0.76,0.80), 0.96, 0.06),
			Vector3(ex, 0.17, 2.34), Vector3(90,0,0))
		_cm(c, _cylinder(0.056, 0.28, Color(0.06,0.05,0.03), 0.04, 0.98),
			Vector3(ex, 0.17, 2.36), Vector3(90,0,0))

	# 19 -- REAR WING (tall swan-neck posts, wide carbon blade)
	for wx in [-0.70, 0.70]:
		_cm(c, _box(Vector3(0.08, 0.90, 0.20), Color(0.08,0.08,0.10), 0.46),
			Vector3(wx, 0.73, 1.95))
	# Main blade
	_cm(c, _box(Vector3(1.94, 0.16, 0.62), Color(0.08,0.08,0.10), 0.40),
		Vector3(0, 1.34, 1.95))
	_cm(c, _box(Vector3(1.86, 0.08, 0.60), Color(0.10,0.10,0.12), 0.36),
		Vector3(0, 1.23, 1.95))
	# Wicker bill
	_cm(c, _box(Vector3(1.80, 0.07, 0.07), Color(0.08,0.08,0.10), 0.3),
		Vector3(0, 1.29, 2.26))
	# End plates
	for wx in [-0.98, 0.98]:
		_cm(c, _box(Vector3(0.07, 0.40, 0.62), Color(0.08,0.08,0.10), 0.38),
			Vector3(wx, 1.26, 1.95))
	# Trunk lip
	_cm(c, _box(Vector3(2.00, 0.06, 0.24), mid, 0.50), Vector3(0, 0.76, 2.18))

	# 20 -- SIDE SKIRTS (rounded, low)
	for sx in [-1.04, 1.04]:
		var sk = MeshInstance3D.new(); var sk_cm = CylinderMesh.new()
		sk_cm.top_radius = 0.10; sk_cm.bottom_radius = 0.10; sk_cm.height = 3.72; sk_cm.radial_segments = 14
		sk.mesh = sk_cm; sk.scale = Vector3(0.48, 1.0, 1.0); sk.position = Vector3(sx, 0.12, 0)
		sk.rotation_degrees.x = 90
		var skm = StandardMaterial3D.new(); skm.albedo_color = Color(0.07,0.07,0.09); skm.metallic=0.4; skm.roughness=0.45
		sk.set_surface_override_material(0, skm); c.add_child(sk)

	# 21 -- SIDE MIRRORS (aerodynamic)
	for mx in [-1.16, 1.16]:
		_cm(c, _box(Vector3(0.22, 0.13, 0.32), mid.darkened(0.14), 0.44),
			Vector3(mx*1.16, 0.72, 0.82))
		_cm(c, _box(Vector3(0.04, 0.11, 0.26), Color(0.34,0.46,0.60), 0.56),
			Vector3(mx*1.17, 0.72, 0.82))

	# 22 -- BODY CHARACTER LINES + VENTS
	for side in [-1, 1]:
		_cm(c, _box(Vector3(0.04, 0.06, 4.05), lite.lightened(0.25), 0.88),
			Vector3(side*0.92, 0.44, 0))
		_cm(c, _box(Vector3(0.04, 0.04, 3.98), lite.lightened(0.14), 0.80),
			Vector3(side*0.92, 0.28, 0))
		# Rear extractor gill
		_cm(c, _box(Vector3(0.07, 0.28, 0.48), Color(0.08,0.08,0.10), 0.18),
			Vector3(side*1.06, 0.35, 0.52))

	# 23 -- ACCENT STRIPE
	for ax in [-1.05, 1.05]:
		_cm(c, _box(Vector3(0.05, 0.05, 3.85), Color(0,0,0), 0, ac, 2.0), Vector3(ax, 0.38, 0))

	# 24 -- WHEELS (large, 10-spoke, orange callipers)
	var wspec = [
		{p=Vector3(-1.22,0, 1.58), r=WHEEL_R+0.04, w=0.44},
		{p=Vector3( 1.22,0, 1.58), r=WHEEL_R+0.04, w=0.44},
		{p=Vector3(-1.10,0,-1.52), r=WHEEL_R,       w=0.34},
		{p=Vector3( 1.10,0,-1.52), r=WHEEL_R,       w=0.34},
	]
	for ws in wspec:
		var wp = ws.p; var wr = ws.r; var ww = ws.w
		_cm(c, _cylinder(wr,      ww,     Color(0.06,0.06,0.07), 0.04, 0.97), wp, Vector3(0,0,90))
		_cm(c, _cylinder(wr-0.07, ww+0.05, Color(0.17,0.17,0.19), 0.90, 0.08), wp, Vector3(0,0,90))
		_cm(c, _cylinder(wr-0.13, ww-0.02, Color(0.42,0.42,0.46), 0.68, 0.22), wp, Vector3(0,0,90))
		for si in range(3):
			var ang = float(si) * 60.0
			var spA = _box(Vector3(0.062,0.29,ww+0.06), Color(0.21,0.21,0.23), 0.92)
			spA.rotation_degrees.z = 90; spA.rotation_degrees.x = ang; spA.position = wp; c.add_child(spA)
			var spB = _box(Vector3(0.052,0.26,ww+0.05), Color(0.19,0.19,0.21), 0.90)
			spB.rotation_degrees.z = 90; spB.rotation_degrees.x = ang+18.0; spB.position = wp; c.add_child(spB)
		_cm(c, _cylinder(0.11, ww+0.07, Color(0.15,0.15,0.17), 0.92, 0.05), wp, Vector3(0,0,90))
		_cm(c, _cylinder(0.06, ww+0.09, Color(0.80,0.72,0.14), 0.95, 0.06), wp, Vector3(0,0,90))
		# ORANGE BRAKE CALLIPER (iconic Corvette feature)
		_cm(c, _box(Vector3(0.15,0.26,ww-0.02), Color(0.95,0.44,0.04), 0.05),
			wp + Vector3(0, wr*0.62, 0))

	# 25 -- UNDER-GLOW
	var gl = OmniLight3D.new()
	gl.light_color = ac; gl.light_energy = 0.60; gl.omni_range = 4.8
	gl.position = Vector3(0, -0.06, 0); c.add_child(gl)

	return c

# Shared wheel builder used by the simpler (non-sport) car silhouettes below —
# cheaper than the sport car's wheel (no spokes) since these are mostly seen
# from a distance in traffic.
static func _simple_wheel(c: Node3D, wp: Vector3, wr: float, ww: float):
	_cm(c, _cylinder(wr,       ww,      Color(0.05,0.05,0.06), 0.05, 0.95), wp, Vector3(0,0,90))
	_cm(c, _cylinder(wr - 0.10, ww+0.04, Color(0.55,0.55,0.58), 0.75, 0.25), wp, Vector3(0,0,90))
	_cm(c, _cylinder(0.09,      ww+0.06, Color(0.16,0.16,0.18), 0.85, 0.15), wp, Vector3(0,0,90))

# TYPE: HATCHBACK ("Matrix Racer") — short, tall, upright — a hot-hatch, not
# a sports car. Distinct from the sport car in every dimension: shorter body,
# taller roof, near-vertical hatch glass, small roof spoiler instead of a wing.
func _make_car_hatch(bc: Color, ac: Color, is_player: bool) -> Node3D:
	var c = Node3D.new(); c.scale = Vector3(0.80, 0.80, 0.80)
	var dark = bc.darkened(0.40); var mid = bc.darkened(0.16); var lite = bc.lightened(0.20)
	var bm = StandardMaterial3D.new(); bm.albedo_color = bc; bm.metallic = 0.70; bm.roughness = 0.25

	# Body — short and tall
	_cm(c, _box(Vector3(1.74, 0.70, 3.05), bc, 0.6), Vector3(0, 0.55, 0))
	_cm(c, _box(Vector3(1.74, 0.10, 3.05), Color(0.06,0.06,0.08), 0.3), Vector3(0, 0.10, 0))
	# Cabin / roof — tall greenhouse
	_cm(c, _box(Vector3(1.42, 0.58, 1.62), mid, 0.5), Vector3(0, 1.10, -0.05))
	# Windshield (raked) + rear hatch glass (near vertical)
	var gm = StandardMaterial3D.new()
	gm.albedo_color = Color(0.08,0.14,0.22,0.42); gm.metallic=0.15; gm.roughness=0.04
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; gm.cull_mode = BaseMaterial3D.CULL_DISABLED
	var fw = MeshInstance3D.new(); var fwm = BoxMesh.new(); fwm.size = Vector3(1.30, 0.52, 0.08)
	fw.mesh = fwm; fw.set_surface_override_material(0, gm)
	fw.position = Vector3(0, 1.12, 0.78); fw.rotation_degrees.x = -58.0; c.add_child(fw)
	var rw = MeshInstance3D.new(); var rwm = BoxMesh.new(); rwm.size = Vector3(1.30, 0.60, 0.08)
	rw.mesh = rwm; rw.set_surface_override_material(0, gm.duplicate())
	rw.position = Vector3(0, 1.10, -0.86); rw.rotation_degrees.x = 78.0; c.add_child(rw)
	# Hood (short) + front fascia
	_cm(c, _box(Vector3(1.60, 0.08, 0.85), mid, 0.6), Vector3(0, 0.86, 1.42))
	_cm(c, _box(Vector3(1.70, 0.55, 0.10), Color(0.08,0.08,0.11), 0.3), Vector3(0, 0.55, 1.55))
	# Rear hatch panel
	_cm(c, _box(Vector3(1.70, 0.60, 0.10), mid.darkened(0.1), 0.4), Vector3(0, 0.90, -1.55))
	# Small roof spoiler (instead of a big wing)
	_cm(c, _box(Vector3(1.30, 0.06, 0.28), Color(0.08,0.08,0.10), 0.4), Vector3(0, 1.42, -1.30))
	# Headlights / taillights
	for side in [-1, 1]:
		_cm(c, _box(Vector3(0.40, 0.20, 0.08), Color(0,0,0), 0, Color(1.0,0.98,0.92), 6.0),
			Vector3(side*0.68, 0.60, 1.56))
		_cm(c, _box(Vector3(0.30, 0.28, 0.08), Color(0,0,0), 0, Color(0.95,0.04,0.04), 6.0),
			Vector3(side*0.72, 0.90, -1.56))
	# Mirrors
	for mx in [-0.92, 0.92]:
		_cm(c, _box(Vector3(0.18, 0.11, 0.26), mid.darkened(0.1), 0.4), Vector3(mx, 1.02, 0.55))
	# Wheels — 4 corners, upright hatchback stance
	for wp in [Vector3(-0.86,0,1.05), Vector3(0.86,0,1.05), Vector3(-0.86,0,-1.05), Vector3(0.86,0,-1.05)]:
		_simple_wheel(c, wp, WHEEL_R, 0.32)
	var gl = OmniLight3D.new(); gl.light_color = ac; gl.light_energy = 0.55; gl.omni_range = 4.2
	gl.position = Vector3(0, -0.06, 0); c.add_child(gl)
	return c

# TYPE: MUSCLE CAR ("Danger Speed") — long hood, short boxy deck, wide flared
# fenders, round headlights, single centre exhaust. Low and long, not tall.
func _make_car_muscle(bc: Color, ac: Color, is_player: bool) -> Node3D:
	var c = Node3D.new(); c.scale = Vector3(0.80, 0.80, 0.80)
	var mid = bc.darkened(0.16); var lite = bc.lightened(0.20)

	# Long low body
	_cm(c, _box(Vector3(2.05, 0.62, 4.60), bc, 0.6), Vector3(0, 0.48, 0.10))
	_cm(c, _box(Vector3(2.05, 0.08, 4.60), Color(0.06,0.06,0.08), 0.3), Vector3(0, 0.06, 0.10))
	# Long hood (dominant feature)
	_cm(c, _box(Vector3(1.86, 0.10, 2.10), mid, 0.65), Vector3(0, 0.78, 1.55))
	var scoop = _sphere(0.30, lite, 0.7, 0.2); scoop.scale = Vector3(0.9, 0.4, 1.6)
	scoop.position = Vector3(0, 0.86, 1.55); c.add_child(scoop)
	# Cabin — set well back (long-hood/short-deck proportion)
	_cm(c, _box(Vector3(1.60, 0.55, 1.55), mid, 0.5), Vector3(0, 1.06, -0.35))
	var gm = StandardMaterial3D.new()
	gm.albedo_color = Color(0.08,0.14,0.22,0.42); gm.metallic=0.15; gm.roughness=0.04
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; gm.cull_mode = BaseMaterial3D.CULL_DISABLED
	var fw = MeshInstance3D.new(); var fwm = BoxMesh.new(); fwm.size = Vector3(1.50, 0.46, 0.08)
	fw.mesh = fwm; fw.set_surface_override_material(0, gm)
	fw.position = Vector3(0, 1.08, 0.42); fw.rotation_degrees.x = -60.0; c.add_child(fw)
	# Wide flared fenders (front + rear, both sides)
	for fz in [1.55, -1.35]:
		for side in [-1, 1]:
			var fl = _sphere(0.56, mid, 0.7, 0.25); fl.scale = Vector3(0.62, 0.62, 1.1)
			fl.position = Vector3(side*1.02, 0.28, fz); c.add_child(fl)
	# Short boxy trunk deck
	_cm(c, _box(Vector3(1.95, 0.10, 0.95), mid, 0.6), Vector3(0, 0.82, -1.85))
	# Round dual headlights + taillight bar
	for side in [-1, 1]:
		var hl = _cylinder(0.20, 0.10, Color(0,0,0), 0.0, 0.1)
		var hlm = StandardMaterial3D.new(); hlm.albedo_color = Color(1.0,0.98,0.92)
		hlm.emission_enabled = true; hlm.emission = Color(1.0,0.98,0.92); hlm.emission_energy_multiplier = 5.0
		hl.set_surface_override_material(0, hlm)
		hl.position = Vector3(side*0.70, 0.55, 2.28); hl.rotation_degrees.x = 90; c.add_child(hl)
	_cm(c, _box(Vector3(1.95, 0.16, 0.08), Color(0,0,0), 0, Color(0.92,0.04,0.04), 6.0),
		Vector3(0, 0.62, -2.28))
	# Centre-exit exhaust
	_cm(c, _cylinder(0.11, 0.30, Color(0.70,0.70,0.74), 0.9, 0.1), Vector3(0, 0.20, -2.30), Vector3(90,0,0))
	# Mirrors
	for mx in [-1.02, 1.02]:
		_cm(c, _box(Vector3(0.18, 0.11, 0.28), mid.darkened(0.1), 0.4), Vector3(mx, 0.98, 0.20))
	# Wheels — wide stance, big rears
	_simple_wheel(c, Vector3(-1.02,0,1.55), WHEEL_R, 0.40)
	_simple_wheel(c, Vector3( 1.02,0,1.55), WHEEL_R, 0.40)
	_simple_wheel(c, Vector3(-1.06,0,-1.45), WHEEL_R+0.06, 0.48)
	_simple_wheel(c, Vector3( 1.06,0,-1.45), WHEEL_R+0.06, 0.48)
	var gl = OmniLight3D.new(); gl.light_color = ac; gl.light_energy = 0.6; gl.omni_range = 4.8
	gl.position = Vector3(0, -0.06, 0); c.add_child(gl)
	return c

# TYPE: SUPERCAR ("Ghost Phantom") — extreme wedge nose, very low and wide,
# huge rear wing on tall struts. The most aggressive/extreme silhouette.
func _make_car_super(bc: Color, ac: Color, is_player: bool) -> Node3D:
	var c = Node3D.new(); c.scale = Vector3(0.80, 0.80, 0.80)
	var mid = bc.darkened(0.16); var lite = bc.lightened(0.24)

	# Low wide body
	_cm(c, _box(Vector3(2.10, 0.36, 4.30), bc, 0.9, Color.BLACK, 0, 0.12), Vector3(0, 0.28, 0))
	_cm(c, _box(Vector3(2.10, 0.06, 4.30), Color(0.05,0.05,0.06), 0.3), Vector3(0, 0.07, 0))
	# Wedge nose — angled box tapering down at the front
	var nose = _box(Vector3(1.70, 0.30, 1.30), bc, 0.9, Color.BLACK, 0, 0.12)
	nose.rotation_degrees.x = -10.0; nose.position = Vector3(0, 0.26, 2.20); c.add_child(nose)
	# Low cabin bubble
	var cab = _sphere(0.62, mid, 0.85, 0.15); cab.scale = Vector3(1.30, 0.34, 1.30)
	cab.position = Vector3(0, 0.62, -0.15); c.add_child(cab)
	var gm = StandardMaterial3D.new()
	gm.albedo_color = Color(0.06,0.10,0.18,0.40); gm.metallic=0.15; gm.roughness=0.03
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; gm.cull_mode = BaseMaterial3D.CULL_DISABLED
	var fw = MeshInstance3D.new(); var fwm = BoxMesh.new(); fwm.size = Vector3(1.55, 0.30, 0.08)
	fw.mesh = fwm; fw.set_surface_override_material(0, gm)
	fw.position = Vector3(0, 0.68, 0.85); fw.rotation_degrees.x = -68.0; c.add_child(fw)
	# Wide rear haunches
	for side in [-1, 1]:
		var fh = _sphere(0.58, mid, 0.85, 0.2); fh.scale = Vector3(0.50, 0.72, 1.6)
		fh.position = Vector3(side*1.08, 0.22, -1.35); c.add_child(fh)
	# Side intakes
	for side in [-1, 1]:
		_cm(c, _box(Vector3(0.10, 0.20, 1.0), Color(0.06,0.06,0.08), 0.3),
			Vector3(side*1.08, 0.30, -0.60))
	# Huge rear wing on tall struts
	for wx in [-0.75, 0.75]:
		_cm(c, _box(Vector3(0.08, 0.62, 0.16), Color(0.08,0.08,0.10), 0.4), Vector3(wx, 0.55, -2.05))
	_cm(c, _box(Vector3(2.05, 0.10, 0.60), Color(0.08,0.08,0.10), 0.4), Vector3(0, 0.86, -2.05))
	# Thin blade headlights + taillight
	for side in [-1, 1]:
		_cm(c, _box(Vector3(0.44, 0.06, 0.10), Color(0,0,0), 0, Color(1.0,0.98,0.92), 6.0),
			Vector3(side*0.72, 0.40, 2.25))
	_cm(c, _box(Vector3(2.0, 0.07, 0.08), Color(0,0,0), 0, Color(0.95,0.04,0.04), 7.0),
		Vector3(0, 0.42, -2.15))
	# Mirrors
	for mx in [-1.12, 1.12]:
		_cm(c, _box(Vector3(0.16, 0.09, 0.24), mid.darkened(0.14), 0.5), Vector3(mx, 0.62, 0.60))
	# Wheels — very wide stance, low profile
	_simple_wheel(c, Vector3(-1.08,0,1.45), WHEEL_R, 0.42)
	_simple_wheel(c, Vector3( 1.08,0,1.45), WHEEL_R, 0.42)
	_simple_wheel(c, Vector3(-1.14,0,-1.45), WHEEL_R+0.08, 0.50)
	_simple_wheel(c, Vector3( 1.14,0,-1.45), WHEEL_R+0.08, 0.50)
	var gl = OmniLight3D.new(); gl.light_color = ac; gl.light_energy = 0.7; gl.omni_range = 5.2
	gl.position = Vector3(0, -0.06, 0); c.add_child(gl)
	return c

# TYPE: SUV ("Elite Guardian") — tall ride height, boxy body, roof rails,
# big wheels. The tallest and most upright silhouette of the five.
func _make_car_suv(bc: Color, ac: Color, is_player: bool) -> Node3D:
	var c = Node3D.new(); c.scale = Vector3(0.80, 0.80, 0.80)
	var mid = bc.darkened(0.16); var lite = bc.lightened(0.20)

	# Tall boxy body, raised off the ground
	_cm(c, _box(Vector3(1.95, 1.05, 4.20), bc, 0.5), Vector3(0, 0.86, 0))
	_cm(c, _box(Vector3(1.90, 0.16, 4.10), Color(0.06,0.06,0.08), 0.3), Vector3(0, 0.28, 0))
	# Hood
	_cm(c, _box(Vector3(1.80, 0.12, 1.20), mid, 0.5), Vector3(0, 1.24, 1.62))
	# Upright grille
	_cm(c, _box(Vector3(1.55, 0.42, 0.10), Color(0.08,0.08,0.11), 0.4), Vector3(0, 1.00, 2.22))
	var gm = StandardMaterial3D.new()
	gm.albedo_color = Color(0.10,0.15,0.22,0.42); gm.metallic=0.15; gm.roughness=0.05
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; gm.cull_mode = BaseMaterial3D.CULL_DISABLED
	var fw = MeshInstance3D.new(); var fwm = BoxMesh.new(); fwm.size = Vector3(1.62, 0.62, 0.08)
	fw.mesh = fwm; fw.set_surface_override_material(0, gm)
	fw.position = Vector3(0, 1.55, 1.05); fw.rotation_degrees.x = -48.0; c.add_child(fw)
	var rw = MeshInstance3D.new(); var rwm = BoxMesh.new(); rwm.size = Vector3(1.62, 0.90, 0.08)
	rw.mesh = rwm; rw.set_surface_override_material(0, gm.duplicate())
	rw.position = Vector3(0, 1.50, -1.15); rw.rotation_degrees.x = 66.0; c.add_child(rw)
	# Roof rails
	for side in [-0.62, 0.62]:
		_cm(c, _box(Vector3(0.07, 0.07, 2.6), Color(0.14,0.14,0.16), 0.6), Vector3(side, 1.98, -0.1))
	# Rear tailgate
	_cm(c, _box(Vector3(1.90, 0.95, 0.12), mid.darkened(0.1), 0.4), Vector3(0, 1.30, -2.05))
	# Square headlights / taillights
	for side in [-1, 1]:
		_cm(c, _box(Vector3(0.36, 0.26, 0.08), Color(0,0,0), 0, Color(1.0,0.98,0.92), 6.0),
			Vector3(side*0.75, 1.05, 2.28))
		_cm(c, _box(Vector3(0.30, 0.40, 0.08), Color(0,0,0), 0, Color(0.95,0.04,0.04), 6.0),
			Vector3(side*0.78, 1.35, -2.10))
	# Side steps
	for side in [-1, 1]:
		_cm(c, _box(Vector3(0.12, 0.06, 2.6), Color(0.14,0.14,0.16), 0.5), Vector3(side*1.02, 0.32, 0))
	# Mirrors
	for mx in [-1.02, 1.02]:
		_cm(c, _box(Vector3(0.20, 0.13, 0.30), mid.darkened(0.1), 0.4), Vector3(mx, 1.42, 1.0))
	# Wheels — bigger, more visible
	_simple_wheel(c, Vector3(-0.95,0,1.45), WHEEL_R+0.10, 0.42)
	_simple_wheel(c, Vector3( 0.95,0,1.45), WHEEL_R+0.10, 0.42)
	_simple_wheel(c, Vector3(-0.95,0,-1.45), WHEEL_R+0.10, 0.42)
	_simple_wheel(c, Vector3( 0.95,0,-1.45), WHEEL_R+0.10, 0.42)
	var gl = OmniLight3D.new(); gl.light_color = ac; gl.light_energy = 0.6; gl.omni_range = 4.8
	gl.position = Vector3(0, -0.06, 0); c.add_child(gl)
	return c

static func _cm(parent: Node3D, mesh: MeshInstance3D,
				pos: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO):
	mesh.position = pos
	if rot != Vector3.ZERO: mesh.rotation_degrees = rot
	parent.add_child(mesh)

# -----------------------------------------------------------------------------
#  Speed particles
# -----------------------------------------------------------------------------
func _build_trail():
	if is_instance_valid(_trail): _trail.queue_free()
	_trail = CPUParticles3D.new()
	_trail.amount = 40; _trail.lifetime = 0.5; _trail.randomness = 0.7
	_trail.direction = Vector3(0, 0.05, 1); _trail.spread = 20.0
	_trail.initial_velocity_min = 3.0; _trail.initial_velocity_max = 9.0
	_trail.scale_amount_min = 0.04; _trail.scale_amount_max = 0.16
	_trail.color = Color(0.6, 0.8, 1.0, 0.4)
	_trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_trail.emission_sphere_radius = 0.4
	_trail.position = Vector3(0, 0.5, 2.5)
	_player.add_child(_trail)

# Cinematic rain — falling streaks anchored to camera so they always surround player
func _build_rain():
	var rain = CPUParticles3D.new()
	rain.amount           = 180
	rain.lifetime         = 0.55
	rain.randomness       = 0.30
	rain.emitting         = true
	rain.direction        = Vector3(0.04, -1.0, 0.08)
	rain.spread           = 4.0
	rain.gravity          = Vector3(0, -28.0, 0)
	rain.initial_velocity_min = 22.0
	rain.initial_velocity_max = 34.0
	rain.scale_amount_min = 0.04
	rain.scale_amount_max = 0.10
	rain.color            = Color(0.65, 0.80, 1.00, 0.28)
	rain.emission_shape   = CPUParticles3D.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(28.0, 0.5, 28.0)
	rain.position = Vector3(0, 12.0, -8.0)
	_cam.add_child(rain)

	# Splash particles at ground level — small splats near the road surface
	var splash = CPUParticles3D.new()
	splash.amount           = 24
	splash.lifetime         = 0.25
	splash.randomness       = 0.8
	splash.emitting         = true
	splash.direction        = Vector3(0, 1, 0)
	splash.spread           = 75.0
	splash.gravity          = Vector3(0, -14.0, 0)
	splash.initial_velocity_min = 0.5
	splash.initial_velocity_max = 2.0
	splash.scale_amount_min = 0.02
	splash.scale_amount_max = 0.06
	splash.color            = Color(0.6, 0.75, 1.0, 0.35)
	splash.emission_shape   = CPUParticles3D.EMISSION_SHAPE_BOX
	splash.emission_box_extents = Vector3(8.0, 0.02, 4.0)
	splash.position = Vector3(0, 0.18, -2.0)
	_player.add_child(splash)

# -----------------------------------------------------------------------------
#  Spawn logic
# -----------------------------------------------------------------------------
func _spawn_logic(delta: float):
	_obs_t += delta
	if _obs_t >= _obs_iv:
		_obs_t = 0.0; _obs_iv = maxf(0.95, _obs_iv - 0.01)
		_do_spawn_enemy()
		if randf() > 0.72: _do_spawn_enemy()
	_cot += delta
	if _cot >= _coiv:
		_cot = 0.0; _do_spawn_coin()

func _do_spawn_enemy():
	var lx = LANE_X[randi() % 4]
	var ec = ENEMY_COLS.pick_random()
	# Don't spawn in player's current lane
	if abs(lx - _player_offset) < 1.0: return
	var model = SettingsManager.CAR_DEFS[randi() % SettingsManager.CAR_DEFS.size()].id
	var en = _make_car(ec, Color.WHITE, false, model)
	var z = SPAWN_Z * 0.82
	var d = _world_dist - z
	en.position = Vector3(lx + _curve_x(d), CAR_Y, z)
	en.rotation.y = atan(_curve_slope(d))
	add_child(en)
	_obs.append({node=en, smult=randf_range(0.75, 1.20)})

func _do_spawn_coin():
	var lx = LANE_X[randi() % 4]
	var coin = _make_coin()
	var z = SPAWN_Z * 0.62
	var d = _world_dist - z
	coin.position = Vector3(lx + _curve_x(d), 0.9, z)
	add_child(coin)
	_coins3.append({node=coin})

func _coin_spin(delta: float):
	for c in _coins3:
		if is_instance_valid(c.node):
			c.node.rotation_degrees.y += 110.0 * delta
			c.node.position.y = 0.9 + sin(Time.get_ticks_msec() * 0.0025) * 0.18

# -----------------------------------------------------------------------------
#  Collision
# -----------------------------------------------------------------------------
func _check_collisions():
	if _gs != GS.PLAYING: return
	var px = _player.position.x
	var pz = _player.position.z  # always ~0

	for i in range(_obs.size() - 1, -1, -1):
		var e = _obs[i]
		if not is_instance_valid(e.node): _obs.remove_at(i); continue
		var dx = abs(px - e.node.position.x)
		var dz = abs(pz - e.node.position.z)
		if dx < 2.1 and dz < 3.6:
			_obs.remove_at(i); e.node.queue_free()
			_do_crash(); return

	for i in range(_coins3.size() - 1, -1, -1):
		var c = _coins3[i]
		if not is_instance_valid(c.node): _coins3.remove_at(i); continue
		if abs(px - c.node.position.x) < 2.0 and abs(pz - c.node.position.z) < 2.0:
			_coins3.remove_at(i)
			_burst_coin(c.node.global_position); c.node.queue_free()
			_coins += 1; _score += 10
			var am = get_node_or_null("/root/AudioManager")
			if am: am.play("combo")

func _do_crash():
	_lives -= 1
	var am = get_node_or_null("/root/AudioManager")
	if am: am.play("wrong")
	_cam_shake()
	_hud_flash(Color(0.9, 0.05, 0.05, 0.50))
	if _lives <= 0:
		await get_tree().create_timer(0.7).timeout
		_game_over()

func _cam_shake():
	if not is_instance_valid(_cam): return
	var orig = _cam.position
	var tw = _cam.create_tween()
	for _i in range(6):
		tw.tween_property(_cam, "position",
			orig + Vector3(randf_range(-0.3,0.3), randf_range(-0.15,0.15), 0), 0.055)
	tw.tween_property(_cam, "position", orig, 0.055)

func _hud_flash(col: Color):
	var fl = ColorRect.new()
	fl.color = col; fl.color.a = 0
	fl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fl.z_index = 8; fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(fl)
	var tw = fl.create_tween()
	tw.tween_property(fl, "color:a", col.a, 0.07)
	tw.tween_property(fl, "color:a", 0.0,   0.38)
	tw.tween_callback(fl.queue_free)

func _burst_coin(pos: Vector3):
	var p = CPUParticles3D.new()
	p.one_shot = true; p.explosiveness = 0.9; p.amount = 16
	p.lifetime = 0.65; p.direction = Vector3(0,1,0); p.spread = 65.0
	p.initial_velocity_min = 3.0; p.initial_velocity_max = 8.0
	p.scale_amount_min = 0.06; p.scale_amount_max = 0.20
	p.color = Color(1.0, 0.82, 0.0, 1.0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.35; p.position = pos; add_child(p)
	await get_tree().create_timer(1.5).timeout
	if is_instance_valid(p): p.queue_free()

# -----------------------------------------------------------------------------
#  HUD
# -----------------------------------------------------------------------------
func _build_hud():
	_hud = CanvasLayer.new(); _hud.layer = 2; add_child(_hud)

	# HUD background bar  fills top of screen regardless of viewport width
	var bar = ColorRect.new()
	bar.color = Color(0.03, 0.04, 0.09, 0.92)
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.size.y = 58; bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(bar)

	var sep = ColorRect.new()
	sep.color = Color(0.0, 0.45, 0.60, 0.55)
	sep.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	sep.size.y = 3; sep.position.y = 55
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(sep)

	# All positions below are for 1152x648 viewport
	_l_lives = _hl(68,  14, "LIVES",    Color("#CC3333"), 18)
	_l_score = _hl(228, 14, "Score: 0",  Color("#D4A010"), 17)
	_l_coins = _hl(402, 14, "Coins: 0", Color("#C8900A"), 17)

	# Speed bar
	var sb = ColorRect.new()
	sb.color = Color(0.10,0.12,0.18)
	sb.position = Vector2(560, 16); sb.size = Vector2(158, 26)
	sb.mouse_filter = Control.MOUSE_FILTER_IGNORE; _hud.add_child(sb)
	_spd_fill = ColorRect.new()
	_spd_fill.color = Color(0.1, 0.7, 0.5); _spd_fill.position = Vector2(561, 17)
	_spd_fill.size = Vector2(0, 24); _spd_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_spd_fill)
	_l_speed = _hl(564, 19, "0 km/h", Color("#3ADD88"), 15)

	# Shop button
	var shop = Button.new(); shop.text = "SHOP"
	shop.position = Vector2(1012, 8); shop.custom_minimum_size = Vector2(50, 42)
	var ss = StyleBoxFlat.new()
	ss.bg_color = Color(0.10, 0.06, 0.22, 0.9)
	ss.border_color = Color(0.50, 0.24, 0.78); ss.set_border_width_all(2); ss.set_corner_radius_all(8)
	shop.add_theme_stylebox_override("normal", ss)
	shop.add_theme_color_override("font_color", Color("#BB88FF"))
	shop.add_theme_font_size_override("font_size", 19)
	_hud.add_child(shop); shop.pressed.connect(_show_shop)

	# Back button
	var back = Button.new(); back.text = "<--"
	back.position = Vector2(10, 8); back.custom_minimum_size = Vector2(46, 42)
	var bs = StyleBoxFlat.new()
	bs.bg_color = Color(0.04, 0.08, 0.16, 0.9)
	bs.border_color = Color(0.12, 0.36, 0.70); bs.set_border_width_all(2); bs.set_corner_radius_all(8)
	back.add_theme_stylebox_override("normal", bs)
	back.add_theme_color_override("font_color", Color("#7AB0E0"))
	back.add_theme_font_size_override("font_size", 20)
	_hud.add_child(back)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/garage.tscn"))

	# Quit button
	var quit_btn = Button.new(); quit_btn.text = "QUIT"
	quit_btn.position = Vector2(1072, 8); quit_btn.custom_minimum_size = Vector2(70, 42)
	var qs = StyleBoxFlat.new()
	qs.bg_color = Color(0.16, 0.04, 0.04, 0.9)
	qs.border_color = Color(0.52, 0.16, 0.16); qs.set_border_width_all(2); qs.set_corner_radius_all(8)
	quit_btn.add_theme_stylebox_override("normal", qs)
	var qsh = qs.duplicate() as StyleBoxFlat
	qsh.bg_color = Color(0.34, 0.08, 0.08, 0.96); qsh.border_color = Color(0.80, 0.28, 0.28)
	quit_btn.add_theme_stylebox_override("hover", qsh)
	quit_btn.add_theme_color_override("font_color", Color("#CC5555"))
	quit_btn.add_theme_font_size_override("font_size", 16)
	_hud.add_child(quit_btn)
	quit_btn.pressed.connect(get_tree().quit)

	_build_touch_controls()

func _build_touch_controls():
	# On-screen D-pad for touch/mobile — always shown so it also works with a mouse
	var mk_btn = func(txt: String, pos: Vector2) -> Button:
		var b = Button.new(); b.text = txt
		b.position = pos; b.custom_minimum_size = Vector2(64, 64)
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(0.06, 0.10, 0.08, 0.55)
		sb.border_color = Color(0.20, 0.70, 0.40, 0.85); sb.set_border_width_all(2)
		sb.set_corner_radius_all(14)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_font_size_override("font_size", 26)
		b.add_theme_color_override("font_color", Color(0.85, 1.0, 0.90))
		b.focus_mode = Control.FOCUS_NONE
		_hud.add_child(b)
		return b

	var vp = get_viewport().get_visible_rect().size
	var left_btn  = mk_btn.call("<",  Vector2(24,          vp.y - 152))
	var right_btn = mk_btn.call(">",  Vector2(24 + 76,     vp.y - 152))
	var up_btn    = mk_btn.call("^",  Vector2(vp.x - 172,  vp.y - 228))
	var down_btn  = mk_btn.call("v",  Vector2(vp.x - 172,  vp.y - 152))

	left_btn.button_down.connect(func():  _touch_left  = true)
	left_btn.button_up.connect(func():    _touch_left  = false)
	right_btn.button_down.connect(func(): _touch_right = true)
	right_btn.button_up.connect(func():   _touch_right = false)
	up_btn.button_down.connect(func():    _touch_up    = true)
	up_btn.button_up.connect(func():      _touch_up    = false)
	down_btn.button_down.connect(func():  _touch_down  = true)
	down_btn.button_up.connect(func():    _touch_down  = false)

func _hl(x: float, y: float, t: String, col: Color, sz: int) -> Label:
	var l = Label.new(); l.text = t; l.position = Vector2(x, y)
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE; _hud.add_child(l); return l

func _refresh_hud(_d: float):
	_l_lives.text = "LIVES: " + str(_lives)
	_l_score.text = "Score: " + str(_score)
	_l_coins.text = "Coins: " + str(_coins)
	var sf = (_speed - SPD_MIN) / (SPD_MAX - SPD_MIN)
	_spd_fill.size.x = sf * 156.0
	_spd_fill.color  = Color(0.05, 0.65 + sf*0.3, 0.45 + sf*0.45)
	_l_speed.text    = str(int(_speed * 9)) + " km/h"

# -----------------------------------------------------------------------------
#  Game Over
# -----------------------------------------------------------------------------
func _game_over():
	_gs = GS.GAME_OVER
	if SettingsManager:
		SettingsManager.race_coins += _coins
		SettingsManager.save_settings()
	var am = get_node_or_null("/root/AudioManager")
	if am: am.play("game_over")
	_show_modal("GAME OVER", Color("#CC2222"),
		"Score: " + str(_score) + "\nCoins this run:  " + str(_coins) +
		"\nTotal coins:  " + str(SettingsManager.race_coins if SettingsManager else _coins),
		[["PLAY AGAIN","#1D9E75"], [" CAR SHOP","#7733BB"], [" Garage","#185FA5"], ["X  Quit Game","#4A1010"]],
		[func(): get_tree().reload_current_scene(),
		 func(): _show_shop(),
		 func(): get_tree().change_scene_to_file("res://scenes/garage.tscn"),
		 func(): get_tree().quit()])

# -----------------------------------------------------------------------------
#  Generic modal (reused for game-over and other screens)
# -----------------------------------------------------------------------------
func _show_modal(title: String, title_col: Color, body: String,
				 buttons: Array, actions: Array):
	var dim = ColorRect.new()
	dim.color = Color(0,0,0,0); dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.z_index = 24; _hud.add_child(dim)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(660, 430)
	panel.z_index = 25; panel.scale = Vector2(0.5,0.5); panel.modulate.a = 0.0
	panel.position = Vector2((1152-660)*0.5, (648-430)*0.5); _hud.add_child(panel)

	var pst = StyleBoxFlat.new()
	pst.bg_color = Color(0.04,0.05,0.12,0.97); pst.border_color = title_col
	pst.set_border_width_all(3); pst.set_corner_radius_all(14)
	pst.content_margin_left = 30; pst.content_margin_right  = 30
	pst.content_margin_top  = 24; pst.content_margin_bottom = 24
	pst.shadow_color = Color(0,0,0,0.75); pst.shadow_size = 14; pst.shadow_offset = Vector2(5,7)
	panel.add_theme_stylebox_override("panel", pst)

	var vb = VBoxContainer.new(); vb.add_theme_constant_override("separation", 14); panel.add_child(vb)

	var t = Label.new(); t.text = title
	t.add_theme_font_size_override("font_size", 46)
	t.add_theme_color_override("font_color", title_col)
	t.add_theme_color_override("font_shadow_color", Color(0,0,0,0.7))
	t.add_theme_constant_override("shadow_offset_x", 3)
	t.add_theme_constant_override("shadow_offset_y", 4)
	vb.add_child(t)

	var bl = Label.new(); bl.text = body
	bl.add_theme_font_size_override("font_size", 20)
	bl.add_theme_color_override("font_color", Color("#EEB800"))
	vb.add_child(bl)

	var ln = ColorRect.new(); ln.color = Color(0.12,0.18,0.32); ln.custom_minimum_size = Vector2(0,2)
	ln.mouse_filter = Control.MOUSE_FILTER_IGNORE; vb.add_child(ln)

	for i in range(buttons.size()):
		var btn = Button.new(); btn.text = "  " + buttons[i][0] + "  "
		btn.custom_minimum_size = Vector2(300, 52)
		StyleManager.style_button(btn, buttons[i][1], "#FFFFFF"); vb.add_child(btn)
		var act = actions[i]
		btn.pressed.connect(func():
			if is_instance_valid(panel): panel.queue_free()
			if is_instance_valid(dim):   dim.queue_free()
			act.call()
		)

	var tw = create_tween(); tw.set_ease(Tween.EASE_OUT); tw.set_trans(Tween.TRANS_BACK)
	tw.tween_property(dim,   "color:a",    0.80, 0.20)
	tw.parallel().tween_property(panel, "scale",      Vector2(1,1), 0.30)
	tw.parallel().tween_property(panel, "modulate:a", 1.0,          0.30)

# -----------------------------------------------------------------------------
#  Car Shop
# -----------------------------------------------------------------------------
func _show_shop():
	var prev = _gs; _gs = GS.SHOP
	var dim = ColorRect.new()
	dim.color = Color(0,0,0,0); dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.z_index = 28; _hud.add_child(dim)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(920, 460)
	panel.z_index = 29; panel.scale = Vector2(0.5,0.5); panel.modulate.a = 0.0
	panel.position = Vector2((1152-920)*0.5, (648-460)*0.5); _hud.add_child(panel)

	var pst = StyleBoxFlat.new()
	pst.bg_color = Color(0.04,0.04,0.14,0.97); pst.border_color = Color(0.55,0.28,0.82)
	pst.set_border_width_all(3); pst.set_corner_radius_all(14)
	pst.content_margin_left = 28; pst.content_margin_right  = 28
	pst.content_margin_top  = 22; pst.content_margin_bottom = 22
	pst.shadow_color = Color(0,0,0,0.75); pst.shadow_size = 14; pst.shadow_offset = Vector2(5,7)
	panel.add_theme_stylebox_override("panel", pst)

	var vb = VBoxContainer.new(); vb.add_theme_constant_override("separation", 12); panel.add_child(vb)

	var hdr = Label.new(); hdr.text = "  CAR GARAGE"
	hdr.add_theme_font_size_override("font_size", 28)
	hdr.add_theme_color_override("font_color", Color("#BB88FF")); vb.add_child(hdr)

	var total = SettingsManager.race_coins if SettingsManager else 0
	var bal = Label.new(); bal.text = "Available Coins:  " + str(total)
	bal.add_theme_font_size_override("font_size", 18)
	bal.add_theme_color_override("font_color", Color("#EEB800")); vb.add_child(bal)

	var ln = ColorRect.new(); ln.color = Color(0.12,0.15,0.30); ln.custom_minimum_size = Vector2(0,2)
	ln.mouse_filter = Control.MOUSE_FILTER_IGNORE; vb.add_child(ln)

	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 8); vb.add_child(row)
	var owned = SettingsManager.race_owned    if SettingsManager else ["blue"]
	var sel   = SettingsManager.race_selected if SettingsManager else "blue"

	for car in SettingsManager.CAR_DEFS:
		var card = VBoxContainer.new(); card.add_theme_constant_override("separation", 5)
		card.custom_minimum_size = Vector2(172, 0)
		var cst = StyleBoxFlat.new()
		cst.bg_color = Color(0.04,0.12,0.04) if car.id == sel else Color(0.06,0.06,0.16)
		cst.border_color = car.accent; cst.set_border_width_all(2 if car.id != sel else 3)
		cst.set_corner_radius_all(10)
		cst.shadow_color = Color(0,0,0,0.5); cst.shadow_size = 6; cst.shadow_offset = Vector2(3,4)
		var cp = PanelContainer.new(); cp.add_theme_stylebox_override("panel", cst)
		var ci = VBoxContainer.new(); ci.add_theme_constant_override("separation", 5)
		cp.add_child(ci); row.add_child(cp)

		var sw = ColorRect.new()
		sw.color = car.body; sw.custom_minimum_size = Vector2(162, 46)
		sw.mouse_filter = Control.MOUSE_FILTER_IGNORE; ci.add_child(sw)
		var ac = ColorRect.new()
		ac.color = car.accent; ac.custom_minimum_size = Vector2(162, 8)
		ac.mouse_filter = Control.MOUSE_FILTER_IGNORE; ci.add_child(ac)

		var nl = Label.new(); nl.text = car.label
		nl.add_theme_font_size_override("font_size", 13)
		nl.add_theme_color_override("font_color", car.accent)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; ci.add_child(nl)

		var is_owned = car.id in owned; var is_sel = car.id == sel
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(158, 36); btn.add_theme_font_size_override("font_size", 13)
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
			if is_instance_valid(panel): panel.queue_free()
			if is_instance_valid(dim):   dim.queue_free()
			_gs = prev; _build_player(); _build_trail(); _show_shop()
		)

	var close = Button.new(); close.text = "  CLOSE  "; close.custom_minimum_size = Vector2(240, 50)
	StyleManager.style_button(close, "#185FA5", "#FFFFFF"); vb.add_child(close)
	close.pressed.connect(func():
		if is_instance_valid(panel): panel.queue_free()
		if is_instance_valid(dim):   dim.queue_free()
		_gs = prev
	)

	var tw = create_tween(); tw.set_ease(Tween.EASE_OUT); tw.set_trans(Tween.TRANS_BACK)
	tw.tween_property(dim,   "color:a",    0.80, 0.18)
	tw.parallel().tween_property(panel, "scale",      Vector2(1,1), 0.28)
	tw.parallel().tween_property(panel, "modulate:a", 1.0,          0.28)

# -----------------------------------------------------------------------------
#  Tutorial
# -----------------------------------------------------------------------------
func _show_tutorial():
	_gs = GS.TUTORIAL
	_show_modal(">>  CYBER RACER 3D", Color("#00AACC"),
		"",
		[["START ENGINE >>>", "#1D9E75"]],
		[func(): _gs = GS.PLAYING])

	# Rebuild modal with tips
	# (show_modal already creates the panel; just append tips before button)
	# Actually _show_modal is generic  for tutorial we need more text
	# Quick approach: call a dedicated _tutorial function

func _show_tutorial_full():
	_gs = GS.TUTORIAL
	var dim = ColorRect.new()
	dim.color = Color(0,0,0,0); dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.z_index = 32; _hud.add_child(dim)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(840, 510)
	panel.z_index = 33; panel.scale = Vector2(0.5,0.5); panel.modulate.a = 0.0
	panel.position = Vector2((1152-840)*0.5, (648-510)*0.5); _hud.add_child(panel)

	var pst = StyleBoxFlat.new()
	pst.bg_color = Color(0.04,0.05,0.12,0.97); pst.border_color = Color(0.0,0.62,0.82)
	pst.set_border_width_all(3); pst.set_corner_radius_all(14)
	pst.content_margin_left = 28; pst.content_margin_right  = 28
	pst.content_margin_top  = 22; pst.content_margin_bottom = 22
	pst.shadow_color = Color(0,0,0,0.75); pst.shadow_size = 14; pst.shadow_offset = Vector2(5,7)
	panel.add_theme_stylebox_override("panel", pst)

	var vb = VBoxContainer.new(); vb.add_theme_constant_override("separation", 10); panel.add_child(vb)

	var t = Label.new(); t.text = ">>  CYBER RACER 3D"
	t.add_theme_font_size_override("font_size", 28)
	t.add_theme_color_override("font_color", Color("#00AACC")); vb.add_child(t)

	var ln = ColorRect.new(); ln.color = Color(0.12,0.18,0.32); ln.custom_minimum_size = Vector2(0,2)
	ln.mouse_filter = Control.MOUSE_FILTER_IGNORE; vb.add_child(ln)

	for tip in [
		["<->  A / D  |  Arrow Keys", "Steer left and right across 4 lanes"],
		["[^]  W / Up Arrow",            "Accelerate  score faster at higher speeds"],
		["[v]  S / Down Arrow",          "Brake  slow down to dodge more easily"],
		["  On-screen buttons",       "Playing on mobile? Use the on-screen arrows to drive"],
		["?[!!]  Crash into enemy car",   "-1 life  keep racing, no stopping!"],
		["  Gold coins on road",      "Drive through to collect  buy new cars in the Shop!"],
		["  Shop (top-right button)", "Spend coins to unlock & equip new race cars"],
	]:
		var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 10); vb.add_child(row)
		var k = Label.new(); k.text = tip[0]
		k.add_theme_font_size_override("font_size", 14); k.add_theme_color_override("font_color", Color("#EEB800"))
		k.custom_minimum_size = Vector2(215, 0); row.add_child(k)
		var v = Label.new(); v.text = tip[1]
		v.add_theme_font_size_override("font_size", 14); v.add_theme_color_override("font_color", Color("#AABBCC"))
		v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; v.custom_minimum_size = Vector2(490, 0); row.add_child(v)

	var play = Button.new(); play.text = "  START ENGINE >>>  "; play.custom_minimum_size = Vector2(300, 52)
	StyleManager.style_button(play, "#1D9E75", "#FFFFFF"); vb.add_child(play)
	play.pressed.connect(func():
		var tw2 = create_tween(); tw2.set_ease(Tween.EASE_IN)
		tw2.tween_property(panel, "scale",      Vector2(0.5,0.5), 0.18)
		tw2.parallel().tween_property(panel, "modulate:a", 0.0,         0.18)
		tw2.parallel().tween_property(dim,   "color:a",    0.0,         0.18)
		tw2.tween_callback(func():
			if is_instance_valid(panel): panel.queue_free()
			if is_instance_valid(dim):   dim.queue_free()
			_gs = GS.PLAYING
		)
	)

	var tw = create_tween(); tw.set_ease(Tween.EASE_OUT); tw.set_trans(Tween.TRANS_BACK)
	tw.tween_property(dim,   "color:a",    0.80, 0.20)
	tw.parallel().tween_property(panel, "scale",      Vector2(1,1), 0.30)
	tw.parallel().tween_property(panel, "modulate:a", 1.0,          0.30)

# -----------------------------------------------------------------------------
#  3D mesh helpers
# -----------------------------------------------------------------------------
static func _box(sz: Vector3, col: Color, metallic: float = 0.0,
				 emission: Color = Color.BLACK, em_e: float = 0.0,
				 roughness: float = 0.62) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var bm = BoxMesh.new(); bm.size = sz; mi.mesh = bm
	var mat = StandardMaterial3D.new()
	mat.albedo_color = col; mat.metallic = metallic; mat.roughness = roughness
	if em_e > 0.01:
		mat.emission_enabled = true; mat.emission = emission
		mat.emission_energy_multiplier = em_e
	mi.set_surface_override_material(0, mat)
	return mi

static func _sphere(radius: float, col: Color,
					metallic: float = 0.0, roughness: float = 0.92) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var sm = SphereMesh.new()
	sm.radius = radius; sm.height = radius * 2.0
	sm.radial_segments = 14; sm.rings = 7
	mi.mesh = sm
	var mat = StandardMaterial3D.new()
	mat.albedo_color = col; mat.metallic = metallic; mat.roughness = roughness
	mi.set_surface_override_material(0, mat)
	return mi

static func _cylinder(radius: float, height: float, col: Color,
					   metallic: float = 0.3, roughness: float = 0.65) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var cm = CylinderMesh.new(); cm.top_radius = radius; cm.bottom_radius = radius; cm.height = height
	mi.mesh = cm
	var mat = StandardMaterial3D.new()
	mat.albedo_color = col; mat.metallic = metallic; mat.roughness = roughness
	mi.set_surface_override_material(0, mat)
	return mi

static func _make_coin() -> Node3D:
	var root = Node3D.new()
	var mi = MeshInstance3D.new(); var cm = CylinderMesh.new()
	cm.top_radius = 0.50; cm.bottom_radius = 0.50; cm.height = 0.18
	mi.mesh = cm
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color("#FFD020"); mat.metallic = 0.92; mat.roughness = 0.08
	mat.emission_enabled = true; mat.emission = Color("#FFA000")
	mat.emission_energy_multiplier = 2.0
	mi.set_surface_override_material(0, mat); root.add_child(mi)
	var inner = MeshInstance3D.new(); var im = CylinderMesh.new()
	im.top_radius = 0.30; im.bottom_radius = 0.30; im.height = 0.20
	inner.mesh = im
	var im2 = StandardMaterial3D.new()
	im2.albedo_color = Color("#A06800"); im2.metallic = 0.80; im2.roughness = 0.15
	inner.set_surface_override_material(0, im2); root.add_child(inner)
	var gl = OmniLight3D.new()
	gl.light_color = Color("#FFD040"); gl.light_energy = 1.6; gl.omni_range = 3.8
	root.add_child(gl)
	root.rotation_degrees.x = 90.0
	return root
