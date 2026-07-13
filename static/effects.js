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

/* ── Silk: soft flowing fabric-like noise, rendered at low-res and
   upscaled (the blur from upscaling is what gives it a silky softness). ── */
function initSilk(canvas, opts = {}) {
  const cfg = Object.assign({
    color: '#7B7481', speed: 5, scale: 1, noiseIntensity: 1.5, rotation: 0,
  }, opts);

  const { r, g, b } = hexToRgb(cfg.color);
  const ctx = canvas.getContext('2d');
  const BUF = 96;
  const buf = document.createElement('canvas');
  buf.width = BUF; buf.height = BUF;
  const bctx = buf.getContext('2d');
  const img = bctx.createImageData(BUF, BUF);
  let t = 0;

  function resize() { canvas.width = canvas.offsetWidth; canvas.height = canvas.offsetHeight; }
  resize();
  window.addEventListener('resize', resize);

  function frame() {
    const freq = 0.12 * cfg.scale;
    const d = img.data;
    for (let y = 0; y < BUF; y++) {
      for (let x = 0; x < BUF; x++) {
        const i = (y * BUF + x) * 4;
        const n =
          Math.sin(x * freq + t) * 0.5 +
          Math.sin(y * freq * 1.3 - t * 0.8) * 0.5 +
          Math.sin((x + y) * freq * 0.7 + t * 1.4) * 0.4 * cfg.noiseIntensity;
        const v = 0.5 + n * 0.28;
        d[i]     = r; d[i + 1] = g; d[i + 2] = b;
        d[i + 3] = Math.max(0, Math.min(255, v * 150));
      }
    }
    bctx.putImageData(img, 0, 0);

    const w = canvas.width, h = canvas.height;
    ctx.clearRect(0, 0, w, h);
    ctx.save();
    ctx.translate(w / 2, h / 2);
    ctx.rotate(cfg.rotation * Math.PI / 180);
    ctx.imageSmoothingEnabled = true;
    const diag = Math.sqrt(w * w + h * h);
    ctx.drawImage(buf, -diag / 2, -diag / 2, diag, diag);
    ctx.restore();

    t += 0.008 * cfg.speed;
    requestAnimationFrame(frame);
  }
  frame();
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
