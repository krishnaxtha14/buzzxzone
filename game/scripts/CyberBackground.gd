extends ColorRect

const SHADER_CODE = """
shader_type canvas_item;

void fragment() {
    vec2 uv = UV;
    float t = TIME;

    // ── Deep space base ──────────────────────────────────────────────────────
    vec3 col = mix(vec3(0.02, 0.0, 0.08), vec3(0.0, 0.05, 0.15), uv.y);

    // ── HEXAGON GRID ─────────────────────────────────────────────────────────
    vec2 hex_uv = uv * vec2(20.0, 11.5);
    vec2 hex_r  = vec2(1.0, 1.73);
    vec2 hex_h  = hex_r * 0.5;
    vec2 ha = mod(hex_uv,        hex_r) - hex_h;
    vec2 hb = mod(hex_uv - hex_h, hex_r) - hex_h;
    vec2 hg = dot(ha,ha) < dot(hb,hb) ? ha : hb;
    float hex = smoothstep(0.48, 0.45,
        max(abs(hg.x), abs(hg.y * 0.57735 + hg.x * 0.5)));
    float hex_pulse = sin(t * 0.5 + uv.x * 3.0 + uv.y * 2.0) * 0.5 + 0.5;
    vec3  hex_color = mix(vec3(0.0, 0.5, 1.0), vec3(0.5, 0.0, 1.0), hex_pulse);
    col += hex_color * hex * 0.30;

    // ── MATRIX RAIN (GREEN) ───────────────────────────────────────────────────
    for (int i = 0; i < 20; i++) {
        float fi    = float(i);
        float cx    = fract(fi * 0.137);
        float speed = 0.3 + fract(fi * 0.419) * 0.7;
        float off   = fract(fi * 0.731);
        float cy    = fract(off + t * speed);
        float dx    = exp(-abs(uv.x - cx) * 80.0);
        float trail = exp(-max(uv.y - cy, 0.0) * 20.0) * step(uv.y, cy + 0.12);
        float head  = exp(-abs(uv.y - cy) * 400.0);
        col += vec3(0.0, 1.0, 0.3) * dx * trail * 1.6;
        col += vec3(0.7, 1.0, 0.8) * dx * head  * 2.2;
    }

    // ── CYAN CIRCUIT LINES ───────────────────────────────────────────────────
    for (int i = 0; i < 5; i++) {
        float fi = float(i);
        float ly  = fract(fi * 0.183 + t * 0.04);
        float lw  = exp(-abs(uv.y - ly) * 200.0);
        float dsh = step(0.4, fract(uv.x * 8.0 - t * 0.5));
        col += vec3(0.0, 1.0, 1.0) * lw * dsh * 0.55;
    }

    // ── PURPLE VERTICAL PULSES ───────────────────────────────────────────────
    for (int i = 0; i < 4; i++) {
        float fi = float(i);
        float vx  = fract(fi * 0.271 + t * 0.02);
        float vw  = exp(-abs(uv.x - vx) * 150.0);
        float dsh = step(0.5, fract(uv.y * 6.0 + t * 0.3));
        col += vec3(0.8, 0.0, 1.0) * vw * dsh * 0.45;
    }

    // ── GLOWING NODES ────────────────────────────────────────────────────────
    for (int i = 0; i < 7; i++) {
        float fi  = float(i);
        vec2  np  = vec2(fract(fi * 0.273), fract(fi * 0.618));
        float nd  = length(uv - np);
        float pls = sin(t * 1.5 + fi * 1.3) * 0.5 + 0.5;
        float glw = exp(-nd * 15.0) * pls;
        vec3  nc  = mix(vec3(0.0, 1.0, 1.0), vec3(1.0, 0.0, 1.0), fract(fi * 0.4));
        col += nc * glw * 0.75;
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  RETROWAVE 3-D PERSPECTIVE FLOOR  (lower 38% of screen)
    // ══════════════════════════════════════════════════════════════════════════
    float horizon = 0.62;
    if (uv.y > horizon) {
        float fp    = (uv.y - horizon) / (1.0 - horizon);   // 0→1 top→bottom
        float depth = fp * fp;                               // non-linear depth

        // World-space grid coords with forward motion
        float px = (uv.x - 0.5) / max(depth, 0.002) * 0.28;
        float pz =  1.0          / max(depth, 0.002) * 0.055 + t * 0.38;

        // Grid lines
        float gx = abs(fract(px) - 0.5);
        float gz = abs(fract(pz) - 0.5);
        float side_fade = smoothstep(1.0, 0.55, abs(uv.x - 0.5) * 2.2);
        float lx = smoothstep(0.46, 0.40, gx) * side_fade;
        float lz = smoothstep(0.46, 0.40, gz);
        float near_fade = smoothstep(0.0, 0.12, fp);
        float far_fade  = smoothstep(1.0, 0.65, uv.y);
        float grid = max(lx, lz) * near_fade * far_fade;

        // Color cycles between cyan and magenta
        float phase  = sin(pz * 0.4 + t * 0.6) * 0.5 + 0.5;
        vec3  grid_c = mix(vec3(0.0, 1.0, 1.0), vec3(1.0, 0.0, 1.0), phase);

        // Horizon line glow (hot pink)
        float h_glow = exp(-fp * 7.0) * 0.30;

        // Darken the matrix content on the floor zone, then add grid
        col = mix(col, col * 0.12, fp * 0.75);
        col += grid_c * grid * 0.90;
        col += vec3(1.0, 0.1, 0.85) * h_glow;
    }

    // ── SCAN LINE ────────────────────────────────────────────────────────────
    float scan = sin(uv.y * 200.0 - t * 5.0) * 0.5 + 0.5;
    col += vec3(0.3, 0.6, 1.0) * scan * 0.035;

    // ── VIGNETTE ─────────────────────────────────────────────────────────────
    vec2 v = uv - 0.5;
    col *= 1.0 - dot(v, v) * 1.7;

    // ── COLOUR ABERRATION EDGE GLOW ──────────────────────────────────────────
    col += vec3(1.0, 0.0, 0.5) * (1.0 - uv.x) * 0.055;
    col += vec3(0.0, 0.5, 1.0) * uv.x          * 0.055;
    col += vec3(0.3, 0.0, 1.0) * (1.0 - uv.y)  * 0.07;

    COLOR = vec4(col, 1.0);
}
"""

func _ready() -> void:
	anchor_left   = 0.0; anchor_top    = 0.0
	anchor_right  = 1.0; anchor_bottom = 1.0
	offset_left   = 0;   offset_top    = 0
	offset_right  = 0;   offset_bottom = 0
	var shader  = Shader.new()
	shader.code = SHADER_CODE
	var mat     = ShaderMaterial.new()
	mat.shader  = shader
	material    = mat
	z_index     = -10
	mouse_filter = Control.MOUSE_FILTER_IGNORE
