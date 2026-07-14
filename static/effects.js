/* ─────────────────────────────────────────────────────────────────────────
   BuzzXzone background effects — plain <canvas> + JS.
   (This app is server-rendered Flask + vanilla JS, no React/bundler, so these
   are hand-ported equivalents of the ColorBends / DotField component specs
   rather than literal component imports.)
───────────────────────────────────────────────────────────────────────── */

function hexToRgb(hex) {
  const h = hex.replace('#', '');
  const n = parseInt(h.length === 3 ? h.split('').map(c => c + c).join('') : h, 16);
  return { r: (n >> 16) & 255, g: (n >> 8) & 255, b: n & 255 };
}

/* ── Real green-screen chroma-key: the brand clips are shot on pure
   rgb(0,254,0). Keyed by green-dominance (green minus the stronger of
   red/blue) rather than flat distance-to-a-swatch, which holds up better
   on anti-aliased edges; edge pixels also get their green channel pulled
   down ("despill") so they don't keep a green fringe once transparent
   compositing is applied over a dark page. ── */
function initChromaVideo(video, canvas, opts = {}) {
  const cfg = Object.assign({
    lowCut:  40,   // greenness below this => fully opaque (real content)
    highCut: 90,   // greenness above this => fully transparent (pure screen)
    width:   canvas.width  || canvas.offsetWidth  || 160,
    height:  canvas.height || canvas.offsetHeight || 160,
  }, opts);

  canvas.width = cfg.width;
  canvas.height = cfg.height;
  const ctx = canvas.getContext('2d', { willReadFrequently: true });

  function frame() {
    if (video.readyState >= 2) {
      ctx.drawImage(video, 0, 0, canvas.width, canvas.height);
      const img = ctx.getImageData(0, 0, canvas.width, canvas.height);
      const d = img.data;
      for (let i = 0; i < d.length; i += 4) {
        const r = d[i], g = d[i + 1], b = d[i + 2];
        const greenness = g - Math.max(r, b);
        if (greenness >= cfg.highCut) {
          d[i + 3] = 0;
        } else if (greenness > cfg.lowCut) {
          const t = (greenness - cfg.lowCut) / (cfg.highCut - cfg.lowCut);
          d[i + 3] = Math.round(255 * (1 - t));
          d[i + 1] = Math.round(g - t * greenness); // despill the fringe
        }
      }
      ctx.putImageData(img, 0, 0);
    }
    requestAnimationFrame(frame);
  }
  frame();
}

/* ── ColorBends: soft flowing colour bands, rotated, fading out near the top ── */
function initColorBends(canvas, opts = {}) {
  const cfg = Object.assign({
    color: '#A855F7', speed: 0.2, frequency: 1.0, noise: 0.15,
    bandWidth: 0.14, rotation: 90, fadeTop: 0.75, iterations: 1, intensity: 1.3,
  }, opts);

  const ctx = canvas.getContext('2d');
  const { r, g, b } = hexToRgb(cfg.color);
  let t = 0;

  function resize() { canvas.width = canvas.offsetWidth; canvas.height = canvas.offsetHeight; }
  resize();
  window.addEventListener('resize', resize);

  function frame() {
    const w = canvas.width, h = canvas.height;
    ctx.clearRect(0, 0, w, h);
    ctx.save();
    ctx.translate(w / 2, h / 2);
    ctx.rotate(cfg.rotation * Math.PI / 180);
    const diag = Math.sqrt(w * w + h * h);
    ctx.translate(-diag / 2, -diag / 2);

    const bandH = diag * cfg.bandWidth;
    const nBands = Math.ceil(diag / bandH) + 2;
    for (let iter = 0; iter < cfg.iterations; iter++) {
      for (let i = -1; i < nBands; i++) {
        const phase = i * cfg.frequency + t * cfg.speed + iter * 1.7;
        const wobble = Math.sin(phase) * (1 + Math.sin(phase * 2.3) * cfg.noise);
        const y = i * bandH + wobble * bandH * 0.5;
        const alpha = (0.5 + 0.5 * Math.sin(phase)) * 0.16 * cfg.intensity / cfg.iterations;
        const grd = ctx.createLinearGradient(0, y, 0, y + bandH);
        grd.addColorStop(0,   `rgba(${r},${g},${b},0)`);
        grd.addColorStop(0.5, `rgba(${r},${g},${b},${alpha})`);
        grd.addColorStop(1,   `rgba(${r},${g},${b},0)`);
        ctx.fillStyle = grd;
        ctx.fillRect(0, y, diag, bandH);
      }
    }
    ctx.restore();

    // Fade out toward the top of the real canvas
    if (cfg.fadeTop > 0) {
      const fadeH = h * cfg.fadeTop;
      const fg = ctx.createLinearGradient(0, 0, 0, fadeH);
      fg.addColorStop(0, 'rgba(5,8,14,1)');
      fg.addColorStop(1, 'rgba(5,8,14,0)');
      ctx.fillStyle = fg;
      ctx.fillRect(0, 0, w, fadeH);
    }

    t += 0.016;
    requestAnimationFrame(frame);
  }
  frame();
}

/* ── Silk: 1:1 port of reactbits.dev's Silk component fragment shader
   (originally a Three.js/GLSL shader — ported line-for-line to JS/canvas
   since this app has no WebGL build pipeline). Rendered at a reduced
   buffer size and upscaled for performance; the upscale blur also happens
   to read as "silk" softness, matching the original's look. ── */
function initSilk(canvas, opts = {}) {
  const cfg = Object.assign({
    color: '#7B7481', speed: 5, scale: 1, noiseIntensity: 1.5, rotation: 0,
  }, opts);

  const { r, g, b } = hexToRgb(cfg.color);
  const ctx = canvas.getContext('2d');
  const BUF = 160;
  const buf = document.createElement('canvas');
  buf.width = BUF; buf.height = BUF;
  const bctx = buf.getContext('2d');
  const img = bctx.createImageData(BUF, BUF);
  const E = Math.E;
  const rotSin = Math.sin(cfg.rotation);
  const rotCos = Math.cos(cfg.rotation);
  let uTime = 0, lastTs = 0;

  function resize() { canvas.width = canvas.offsetWidth; canvas.height = canvas.offsetHeight; }
  resize();
  window.addEventListener('resize', resize);

  // noise(texCoord) — GLSL: fract(r.x*r.y*(1+texCoord.x)) where r = e*sin(e*texCoord)
  function noise2(px, py) {
    const rx = E * Math.sin(E * px);
    const ry = E * Math.sin(E * py);
    const v = rx * ry * (1 + px);
    return v - Math.floor(v);
  }

  function frame(ts) {
    if (!lastTs) lastTs = ts;
    const delta = (ts - lastTs) / 1000;
    lastTs = ts;
    uTime += 0.1 * delta;
    const tOffset = cfg.speed * uTime;

    const d = img.data;
    for (let py = 0; py < BUF; py++) {
      const vUvY = py / BUF;
      for (let px = 0; px < BUF; px++) {
        const vUvX = px / BUF;
        // uv = rotate(vUv * scale, rotation); tex = uv * scale
        let ux = vUvX * cfg.scale, uy = vUvY * cfg.scale;
        const rux = ux * rotCos - uy * rotSin;
        const ruy = ux * rotSin + uy * rotCos;
        let tx = rux * cfg.scale, ty = ruy * cfg.scale;
        ty += 0.03 * Math.sin(8.0 * tx - tOffset);

        const pattern = 0.6 + 0.4 * Math.sin(
          5.0 * (tx + ty + Math.cos(3.0 * tx + 5.0 * ty) + 0.02 * tOffset) +
          Math.sin(20.0 * (tx + ty - 0.1 * tOffset))
        );
        const rnd = noise2(px, py); // gl_FragCoord.xy — screen-space pixel coords
        const shade = pattern - (rnd / 15) * cfg.noiseIntensity;

        const i = (py * BUF + px) * 4;
        d[i]     = Math.max(0, Math.min(255, r * shade));
        d[i + 1] = Math.max(0, Math.min(255, g * shade));
        d[i + 2] = Math.max(0, Math.min(255, b * shade));
        d[i + 3] = 255;
      }
    }
    bctx.putImageData(img, 0, 0);

    const w = canvas.width, h = canvas.height;
    ctx.imageSmoothingEnabled = true;
    ctx.drawImage(buf, 0, 0, w, h);

    requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);
}

/* ── TextPressure: a heading whose per-letter weight/width/slant reacts to
   cursor proximity, via a variable font's font-variation-settings axes.
   Uses Roboto Flex (hosted free on Google Fonts) since it actually exposes
   wght/wdth axes — most fonts don't, so this needs a variable font. ── */
function initTextPressure(container, opts = {}) {
  const cfg = Object.assign({
    text: 'BUZZXZONE',
    minFontSize: 36,
    textColor: '#ece3fb',
    width: true, weight: true, italic: true,
  }, opts);

  if (!document.getElementById('text-pressure-font')) {
    const link = document.createElement('link');
    link.id = 'text-pressure-font';
    link.rel = 'stylesheet';
    link.href = 'https://fonts.googleapis.com/css2?family=Roboto+Flex:opsz,wdth,wght@8..144,25..151,100..1000&display=swap';
    document.head.appendChild(link);
  }

  container.style.position = 'relative';
  container.style.width = '100%';
  const title = document.createElement('h1');
  title.style.cssText = `font-family:'Roboto Flex',sans-serif; text-transform:uppercase; ` +
    `margin:0; text-align:center; user-select:none; white-space:nowrap; ` +
    `font-weight:100; width:100%; color:${cfg.textColor}; display:flex; justify-content:space-between;`;
  container.appendChild(title);

  const spans = cfg.text.split('').map(ch => {
    const span = document.createElement('span');
    span.textContent = ch;
    span.style.display = 'inline-block';
    title.appendChild(span);
    return span;
  });

  function setSize() {
    const w = container.getBoundingClientRect().width;
    title.style.fontSize = Math.max(w / (spans.length / 2), cfg.minFontSize) + 'px';
  }
  setSize();
  window.addEventListener('resize', setSize);

  const mouse  = { x: innerWidth / 2, y: innerHeight / 2 };
  const cursor = { x: mouse.x, y: mouse.y };
  addEventListener('mousemove', e => { cursor.x = e.clientX; cursor.y = e.clientY; }, { passive: true });
  addEventListener('touchmove', e => {
    const t = e.touches[0]; cursor.x = t.clientX; cursor.y = t.clientY;
  }, { passive: true });

  function attrAt(distance, maxDist, minVal, maxVal) {
    const v = maxVal - Math.abs(maxVal * distance / maxDist);
    return Math.max(minVal, v + minVal);
  }

  function animate() {
    mouse.x += (cursor.x - mouse.x) / 15;
    mouse.y += (cursor.y - mouse.y) / 15;

    const titleRect = title.getBoundingClientRect();
    const maxDist = titleRect.width / 2;

    for (const span of spans) {
      const r = span.getBoundingClientRect();
      const cx = r.x + r.width / 2, cy = r.y + r.height / 2;
      const d = Math.sqrt((mouse.x - cx) ** 2 + (mouse.y - cy) ** 2);

      const wdth = cfg.width  ? Math.floor(attrAt(d, maxDist, 5, 200))  : 100;
      const wght = cfg.weight ? Math.floor(attrAt(d, maxDist, 100, 900)) : 400;
      const ital = cfg.italic ? attrAt(d, maxDist, 0, 1).toFixed(2) : 0;
      span.style.fontVariationSettings = `'wght' ${wght}, 'wdth' ${wdth}, 'ital' ${ital}`;
    }
    requestAnimationFrame(animate);
  }
  requestAnimationFrame(animate);
}

/* ── DotField: grid of dots that bulge near the cursor ── */
function initDotField(canvas, opts = {}) {
  const cfg = Object.assign({
    dotRadius: 1.5, dotSpacing: 14, cursorRadius: 500, cursorForce: 0.10,
    bulgeOnly: true, bulgeStrength: 67, glowRadius: 160, sparkle: false, waveAmplitude: 0,
  }, opts);

  const ctx = canvas.getContext('2d');
  let mouse = { x: -9999, y: -9999 };
  let t = 0;

  function resize() { canvas.width = canvas.offsetWidth; canvas.height = canvas.offsetHeight; }
  resize();
  window.addEventListener('resize', resize);
  canvas.addEventListener('mousemove', e => {
    const rect = canvas.getBoundingClientRect();
    mouse.x = e.clientX - rect.left; mouse.y = e.clientY - rect.top;
  });
  canvas.addEventListener('mouseleave', () => { mouse.x = -9999; mouse.y = -9999; });
  canvas.addEventListener('touchmove', e => {
    const rect = canvas.getBoundingClientRect();
    const touch = e.touches[0];
    mouse.x = touch.clientX - rect.left; mouse.y = touch.clientY - rect.top;
  }, { passive: true });

  function frame() {
    const w = canvas.width, h = canvas.height;
    ctx.clearRect(0, 0, w, h);
    const cols = Math.ceil(w / cfg.dotSpacing) + 1;
    const rows = Math.ceil(h / cfg.dotSpacing) + 1;

    for (let cx = 0; cx < cols; cx++) {
      for (let cy = 0; cy < rows; cy++) {
        const x = cx * cfg.dotSpacing;
        const y = cy * cfg.dotSpacing;
        const dx = x - mouse.x, dy = y - mouse.y;
        const dist = Math.sqrt(dx * dx + dy * dy);

        let radius = cfg.dotRadius;
        let alpha = 0.18;
        if (dist < cfg.cursorRadius) {
          const proximity = 1 - dist / cfg.cursorRadius;
          const bulge = proximity * proximity * cfg.cursorForce * cfg.bulgeStrength * 0.01;
          radius = cfg.dotRadius * (1 + bulge * 3);
          alpha = Math.min(1, 0.18 + proximity * 0.75);
        }
        if (cfg.waveAmplitude > 0) {
          radius += Math.sin(t * 2 + x * 0.05 + y * 0.05) * cfg.waveAmplitude;
        }

        if (dist < cfg.glowRadius) {
          const glowA = (1 - dist / cfg.glowRadius) * 0.25;
          const grd = ctx.createRadialGradient(x, y, 0, x, y, radius * 4);
          grd.addColorStop(0, `rgba(168,85,247,${glowA})`);
          grd.addColorStop(1, 'rgba(168,85,247,0)');
          ctx.fillStyle = grd;
          ctx.beginPath(); ctx.arc(x, y, radius * 4, 0, Math.PI * 2); ctx.fill();
        }

        ctx.fillStyle = `rgba(216,180,254,${alpha})`;
        ctx.beginPath();
        ctx.arc(x, y, Math.max(0.4, radius), 0, Math.PI * 2);
        ctx.fill();
      }
    }
    t += 0.016;
    requestAnimationFrame(frame);
  }
  frame();
}
