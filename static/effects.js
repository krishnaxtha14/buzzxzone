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
  let skip = 0;

  function frame() {
    // getImageData/putImageData are real work every call — this is a small
    // looping decorative logo, it doesn't need re-keying at full 60fps.
    skip++;
    if (video.readyState >= 2 && skip >= 2) {
      skip = 0;
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

/* ── ColorBends: 1:1 port of reactbits.dev's ColorBends fragment shader
   (originally Three.js/GLSL — ported to canvas 2D since this app has no
   WebGL build pipeline). A continuous per-pixel domain-warp field, not
   discrete gradient bands, which is what makes it read as truly flowing
   instead of a stack of blurry rectangles. ── */
function initColorBends(canvas, opts = {}) {
  const cfg = Object.assign({
    rotation: 90, speed: 0.2, colors: ['#A855F7'], scale: 1, frequency: 1,
    warpStrength: 1, mouseInfluence: 1, parallax: 0.5, noise: 0.15,
    iterations: 1, intensity: 1.5, bandWidth: 6, transparent: true,
  }, opts);
  if (cfg.color && !opts.colors) cfg.colors = [cfg.color]; // accept singular `color` too

  const colorVecs = cfg.colors.map(hex => {
    const c = hexToRgb(hex);
    return [c.r / 255, c.g / 255, c.b / 255];
  });

  const ctx = canvas.getContext('2d');
  // The warp field has real fine-grained texture in it — too small a buffer
  // under-samples that detail and upscaling just smears it into a blurry
  // blob instead of a defined flowing pattern. This needs to be big enough
  // to actually resolve the pattern; the frame-skip below pays for it.
  const BUF = 200;
  const buf = document.createElement('canvas');
  buf.width = BUF; buf.height = BUF;
  const bctx = buf.getContext('2d');
  const img = bctx.createImageData(BUF, BUF);

  const pointer = { x: 0, y: 0 };
  const pointerTarget = { x: 0, y: 0 };
  canvas.addEventListener('mousemove', e => {
    const rect = canvas.getBoundingClientRect();
    pointerTarget.x = ((e.clientX - rect.left) / (rect.width || 1)) * 2 - 1;
    pointerTarget.y = -(((e.clientY - rect.top) / (rect.height || 1)) * 2 - 1);
  }, { passive: true });

  function resize() { canvas.width = canvas.offsetWidth; canvas.height = canvas.offsetHeight; }
  resize();
  window.addEventListener('resize', resize);

  const rotRad = cfg.rotation * Math.PI / 180;
  const rotX = Math.cos(rotRad), rotY = Math.sin(rotRad);
  const kBelow = Math.max(0, Math.min(1, cfg.warpStrength));
  const kMix = Math.pow(kBelow, 0.3);
  const gain = 1 + Math.max(cfg.warpStrength - 1, 0);
  const warpIters = Math.min(Math.max(cfg.iterations - 1, 0), 5);

  let elapsed = 0, lastTs = 0, skip = 0;

  function frame(ts) {
    if (!lastTs) lastTs = ts;
    const dt = (ts - lastTs) / 1000;
    lastTs = ts;
    elapsed += dt;
    pointer.x += (pointerTarget.x - pointer.x) * Math.min(1, dt * 8);
    pointer.y += (pointerTarget.y - pointer.y) * Math.min(1, dt * 8);

    skip++;
    if (skip >= 3) { // recompute at ~20fps — it's a slow ambient field, doesn't need 60fps
      skip = 0;
      const t = elapsed * cfg.speed;
      const aspect = canvas.width / Math.max(1, canvas.height);
      const d = img.data;

      for (let py = 0; py < BUF; py++) {
        const vy = py / BUF;
        for (let px = 0; px < BUF; px++) {
          const vx = px / BUF;
          let px_ = vx * 2 - 1, py_ = vy * 2 - 1;
          px_ += pointer.x * cfg.parallax * 0.1;
          py_ += pointer.y * cfg.parallax * 0.1;

          const rpx = px_ * rotX - py_ * rotY;
          const rpy = px_ * rotY + py_ * rotX;

          let qx = rpx * aspect / Math.max(cfg.scale, 0.0001);
          let qy = rpy / Math.max(cfg.scale, 0.0001);
          const denom = 0.5 + 0.2 * (qx * qx + qy * qy);
          qx /= denom; qy /= denom;
          qx += 0.2 * Math.cos(t) - 7.56;

          qx += (pointer.x - rpx) * cfg.mouseInfluence * 0.2;
          qy += (pointer.y - rpy) * cfg.mouseInfluence * 0.2;

          for (let j = 0; j < warpIters; j++) {
            const rrx = Math.sin(1.5 * (qy * cfg.frequency) + 2 * Math.cos(qx * cfg.frequency));
            const rry = Math.sin(1.5 * (qx * cfg.frequency) + 2 * Math.cos(qy * cfg.frequency));
            qx += (rrx - qx) * 0.15;
            qy += (rry - qy) * 0.15;
          }

          let sx = qx, sy = qy;
          let colR = 0, colG = 0, colB = 0;
          for (let i = 0; i < colorVecs.length; i++) {
            sx -= 0.01; sy -= 0.01;
            const rx = Math.sin(1.5 * (sy * cfg.frequency) + 2 * Math.cos(sx * cfg.frequency));
            const ry = Math.sin(1.5 * (sx * cfg.frequency) + 2 * Math.cos(sy * cfg.frequency));
            const s0 = Math.sin(5 * ry * cfg.frequency - 3 * t + i) / 4;
            const m0 = Math.hypot(rx + s0, ry + s0);

            const dispX = (rx - sx) * kBelow, dispY = (ry - sy) * kBelow;
            const wx = sx + dispX * gain, wy = sy + dispY * gain;
            const s1 = Math.sin(5 * wy * cfg.frequency - 3 * t + i) / 4;
            const m1 = Math.hypot(wx + s1, wy + s1);

            const m = m0 + (m1 - m0) * kMix;
            const w = 1 - Math.exp(-cfg.bandWidth / Math.exp(cfg.bandWidth * m));
            const [cr, cg, cb] = colorVecs[i];
            colR += cr * w; colG += cg * w; colB += cb * w;
          }
          colR = Math.min(1, Math.max(0, colR)) * cfg.intensity;
          colG = Math.min(1, Math.max(0, colG)) * cfg.intensity;
          colB = Math.min(1, Math.max(0, colB)) * cfg.intensity;

          if (cfg.noise > 0.0001) {
            const n = Math.sin((px + t * 60) * 12.9898 + (py + t * 60) * 78.233) * 43758.5453;
            const nf = n - Math.floor(n);
            const nn = (nf - 0.5) * cfg.noise;
            colR = Math.min(1, Math.max(0, colR + nn));
            colG = Math.min(1, Math.max(0, colG + nn));
            colB = Math.min(1, Math.max(0, colB + nn));
          }

          const alpha = cfg.transparent ? Math.max(colR, colG, colB) : 1;
          const i4 = (py * BUF + px) * 4;
          d[i4]     = colR * 255;
          d[i4 + 1] = colG * 255;
          d[i4 + 2] = colB * 255;
          d[i4 + 3] = alpha * 255;
        }
      }
      bctx.putImageData(img, 0, 0);
    }

    const w = canvas.width, h = canvas.height;
    ctx.clearRect(0, 0, w, h);
    ctx.imageSmoothingEnabled = true;
    ctx.imageSmoothingQuality = 'high';
    ctx.drawImage(buf, 0, 0, w, h);

    requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);
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
  const BUF = 72; // small buffer + upscale — this is a slow ambient wash, not worth full-res
  const buf = document.createElement('canvas');
  buf.width = BUF; buf.height = BUF;
  const bctx = buf.getContext('2d');
  const img = bctx.createImageData(BUF, BUF);
  const E = Math.E;
  const rotSin = Math.sin(cfg.rotation);
  const rotCos = Math.cos(cfg.rotation);
  let uTime = 0, lastTs = 0, skip = 0;

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

    // This is a slow ambient wash — recomputing the noise buffer at 60fps is
    // wasted work. Recompute at ~20fps; the upscale draw still happens every
    // frame so resizing/compositing stays smooth.
    skip++;
    if (skip >= 3) {
      skip = 0;
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
    }

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

/* ── Shuffle text: splits text into per-character strips, each holding a
   few scrambled glyphs followed by the real character, then slides the
   strip so the real glyph lands in view — a "letters rolling into place"
   entrance animation. Plays once the element scrolls into view. Built with
   plain CSS transitions (no GSAP dependency) rather than a literal port. ── */
function initShuffleText(el, opts = {}) {
  const cfg = Object.assign({
    direction: 'right', // right | left | up | down
    duration: 450,      // ms per character
    shuffleTimes: 3,    // scrambled glyphs shown before the real one
    stagger: 40,        // ms between each character starting
    scrambleCharset: '', // empty = just show the real char while sliding
  }, opts);

  const text = el.textContent;
  const isVertical = cfg.direction === 'up' || cfg.direction === 'down';
  const reverse = cfg.direction === 'left' || cfg.direction === 'up';

  // Building/measuring character boxes before the real font has loaded bakes
  // in wrong widths (falls back to a system font momentarily) — every glyph
  // then gets clipped once the real font swaps in. Wait for it first.
  const fontsReady = ('fonts' in document) ? document.fonts.ready : Promise.resolve();
  fontsReady.then(buildShuffle);

  function buildShuffle() {
  el.textContent = '';
  const entries = text.split('').map(ch => {
    const wrap = document.createElement('span');
    wrap.style.cssText = 'display:inline-block; overflow:hidden; vertical-align:bottom;';
    const strip = document.createElement('span');
    // flex, not block — block-level glyphs stack as separate lines, which is
    // only right for the vertical (up/down) case. flex-direction lays them
    // out along whichever axis this direction actually animates on.
    strip.style.cssText = `display:flex; flex-direction:${isVertical ? 'column' : 'row'}; will-change:transform;`;
    wrap.appendChild(strip);

    const glyphs = [];
    for (let i = 0; i < cfg.shuffleTimes; i++) {
      const g = document.createElement('span');
      g.style.cssText = 'display:block;';
      g.textContent = cfg.scrambleCharset
        ? cfg.scrambleCharset[Math.floor(Math.random() * cfg.scrambleCharset.length)]
        : (ch === ' ' ? ' ' : ch);
      strip.appendChild(g);
      glyphs.push(g);
    }
    const real = document.createElement('span');
    real.style.cssText = 'display:block;';
    real.textContent = ch === ' ' ? ' ' : ch;
    strip.appendChild(real);
    if (reverse) strip.insertBefore(real, strip.firstChild); // real glyph at the start instead

    el.appendChild(wrap);
    return { wrap, strip };
  });

  function arm() {
    entries.forEach(({ wrap, strip }) => {
      const glyphRect = strip.children[0].getBoundingClientRect();
      const size = isVertical ? glyphRect.height : glyphRect.width;
      wrap.style[isVertical ? 'height' : 'width'] = size + 'px';
      // reverse (left/up) puts the real glyph first in the strip, so its
      // resting position is 0 and it starts offset; right/down is the
      // opposite. Getting these swapped shows the real glyph immediately
      // and "shuffles" into a scrambled one instead of landing on it.
      const offset = -cfg.shuffleTimes * size;
      const startTransform = reverse ? offset : 0;
      const restTransform = reverse ? 0 : offset;
      strip.style.transition = 'none';
      strip.style.transform = isVertical ? `translateY(${startTransform}px)` : `translateX(${startTransform}px)`;
      strip.dataset.restTransform = isVertical ? `translateY(${restTransform}px)` : `translateX(${restTransform}px)`;
    });
  }
  arm();

  function play() {
    entries.forEach(({ strip }, i) => {
      setTimeout(() => {
        strip.style.transition = `transform ${cfg.duration}ms cubic-bezier(0.22,1,0.36,1)`;
        strip.style.transform = strip.dataset.restTransform;
      }, i * cfg.stagger);
    });
  }

  const io = new IntersectionObserver((ents) => {
    ents.forEach(e => {
      if (e.isIntersecting) { play(); io.disconnect(); }
    });
  }, { threshold: 0.1 });
  io.observe(el);
  }
}

/* ── DotField: grid of dots that bulge away from the cursor, with a soft
   glow halo that only lights up while the cursor is actively moving nearby
   (an "engagement" value tracks recent mouse speed) — a static hover does
   nothing, a moving cursor makes the dots push aside and the halo shine. ── */
function initDotField(canvas, opts = {}) {
  const cfg = Object.assign({
    dotRadius: 2, dotSpacing: 14, cursorRadius: 500, cursorForce: 0.10,
    bulgeOnly: true, bulgeStrength: 67, sparkle: false, waveAmplitude: 0,
    dotColor: 'rgba(200,200,212,0.55)',
  }, opts);

  const ctx = canvas.getContext('2d');
  const mouse = { x: -9999, y: -9999, prevX: -9999, prevY: -9999, speed: 0 };
  let dots = [];
  let engagement = 0, frameCount = 0;

  function buildDots(w, h) {
    const step = cfg.dotRadius + cfg.dotSpacing;
    const cols = Math.floor(w / step), rows = Math.floor(h / step);
    const padX = (w % step) / 2, padY = (h % step) / 2;
    dots = [];
    for (let row = 0; row < rows; row++) {
      for (let col = 0; col < cols; col++) {
        const ax = padX + col * step + step / 2;
        const ay = padY + row * step + step / 2;
        dots.push({ ax, ay, sx: ax, sy: ay });
      }
    }
  }

  function resize() {
    canvas.width = canvas.offsetWidth;
    canvas.height = canvas.offsetHeight;
    buildDots(canvas.width, canvas.height);
  }
  resize();
  window.addEventListener('resize', resize);
  window.addEventListener('mousemove', e => {
    const rect = canvas.getBoundingClientRect();
    mouse.x = e.clientX - rect.left; mouse.y = e.clientY - rect.top;
  }, { passive: true });
  window.addEventListener('touchmove', e => {
    const rect = canvas.getBoundingClientRect();
    const touch = e.touches[0];
    mouse.x = touch.clientX - rect.left; mouse.y = touch.clientY - rect.top;
  }, { passive: true });

  setInterval(() => {
    const dx = mouse.prevX - mouse.x, dy = mouse.prevY - mouse.y;
    const dist = Math.sqrt(dx * dx + dy * dy);
    mouse.speed += (dist - mouse.speed) * 0.5;
    if (mouse.speed < 0.001) mouse.speed = 0;
    mouse.prevX = mouse.x; mouse.prevY = mouse.y;
  }, 20);

  // Dots are a single flat colour now — no glow halo, no per-frame gradient
  // rebuild — just the grid pushing away from a moving cursor. Cheap.
  ctx.fillStyle = cfg.dotColor;

  function frame() {
    frameCount++;
    const w = canvas.width, h = canvas.height;
    const t = frameCount * 0.02;

    const targetEngagement = Math.min(mouse.speed / 5, 1);
    engagement += (targetEngagement - engagement) * 0.06;
    if (engagement < 0.001) engagement = 0;

    ctx.clearRect(0, 0, w, h);

    const crSq = cfg.cursorRadius * cfg.cursorRadius;
    const rad = Math.max(0.4, cfg.dotRadius);

    ctx.beginPath();
    for (const d of dots) {
      const dx = mouse.x - d.ax, dy = mouse.y - d.ay;
      const distSq = dx * dx + dy * dy;

      if (distSq < crSq && engagement > 0.01) {
        const dist = Math.sqrt(distSq);
        const tt = 1 - dist / cfg.cursorRadius;
        const push = tt * tt * cfg.bulgeStrength * engagement;
        const angle = Math.atan2(dy, dx);
        d.sx += (d.ax - Math.cos(angle) * push - d.sx) * 0.15;
        d.sy += (d.ay - Math.sin(angle) * push - d.sy) * 0.15;
      } else {
        d.sx += (d.ax - d.sx) * 0.1;
        d.sy += (d.ay - d.sy) * 0.1;
      }

      let drawX = d.sx, drawY = d.sy;
      if (cfg.waveAmplitude > 0) {
        drawY += Math.sin(d.ax * 0.03 + t) * cfg.waveAmplitude;
        drawX += Math.cos(d.ay * 0.03 + t * 0.7) * cfg.waveAmplitude * 0.5;
      }

      ctx.moveTo(drawX + rad, drawY);
      ctx.arc(drawX, drawY, rad, 0, Math.PI * 2);
    }
    ctx.fill();

    requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);
}

/* ── LineWaves: 1:1 port of reactbits.dev's LineWaves fragment shader
   (originally WebGL/ogl — ported to canvas 2D since this app has no WebGL
   build pipeline). Two domain-warped ridge fields are blended together and
   lit per-channel off a slow colour cycle, which is what produces the wavy
   contour-line look rather than plain sine stripes. ── */
function initLineWaves(canvas, opts = {}) {
  const cfg = Object.assign({
    speed: 0.3, innerLineCount: 32, outerLineCount: 36, warpIntensity: 1,
    rotation: -45, edgeFadeWidth: 0, colorCycleSpeed: 1, brightness: 0.2,
    color1: '#ffffff', color2: '#ffffff', color3: '#ffffff',
    enableMouseInteraction: true, mouseInfluence: 2,
  }, opts);

  const c1 = hexToRgb(cfg.color1), c2 = hexToRgb(cfg.color2), c3 = hexToRgb(cfg.color3);
  const col1 = [c1.r / 255, c1.g / 255, c1.b / 255];
  const col2 = [c2.r / 255, c2.g / 255, c2.b / 255];
  const col3 = [c3.r / 255, c3.g / 255, c3.b / 255];
  const HALF_PI = 1.5707963;

  const ctx = canvas.getContext('2d');
  // Fine ridge lines need real resolution to read as lines instead of mush —
  // a fixed small buffer stretched over a large viewport (the original
  // approach here) upscales by 10-15x and the lines dissolve into blur.
  // Instead size the buffer off the actual canvas, aspect-preserved, capped
  // to a pixel budget so cost stays roughly constant regardless of screen size.
  const buf = document.createElement('canvas');
  const bctx = buf.getContext('2d');
  let bufW = 0, bufH = 0, img = null;
  const BUF_BUDGET = 90000;
  function rebuildBuffer() {
    const w = Math.max(1, canvas.width), h = Math.max(1, canvas.height);
    const aspect = w / h;
    let newH = Math.round(Math.sqrt(BUF_BUDGET / aspect));
    let newW = Math.round(newH * aspect);
    newW = Math.max(48, Math.min(newW, 640));
    newH = Math.max(48, Math.min(newH, 640));
    if (newW === bufW && newH === bufH) return;
    bufW = newW; bufH = newH;
    buf.width = bufW; buf.height = bufH;
    img = bctx.createImageData(bufW, bufH);
  }

  const rot = cfg.rotation * Math.PI / 180;
  const rotCos = Math.cos(rot), rotSin = Math.sin(rot);
  function rotate(x, y) {
    return [x * rotCos - y * rotSin, x * rotSin + y * rotCos];
  }
  function frac(x) { return x - Math.floor(x); }
  function smoothstep(edge0, edge1, x) {
    const t = Math.min(1, Math.max(0, (x - edge0) / (edge1 - edge0)));
    return t * t * (3 - 2 * t);
  }
  function hashF(n) { return frac(Math.sin(n * 127.1) * 43758.5453123); }
  function smoothNoise(x) {
    const i = Math.floor(x), f = x - i;
    const u = f * f * (3 - 2 * f);
    return hashF(i) + (hashF(i + 1) - hashF(i)) * u;
  }
  function displaceA(coord, t) {
    let r = Math.sin(coord * 2.123) * 0.2;
    r += Math.sin(coord * 3.234 + t * 4.345) * 0.1;
    r += Math.sin(coord * 0.589 + t * 0.934) * 0.5;
    return r;
  }
  function displaceB(coord, t) {
    let r = Math.sin(coord * 1.345) * 0.3;
    r += Math.sin(coord * 2.734 + t * 3.345) * 0.2;
    r += Math.sin(coord * 0.189 + t * 0.934) * 0.3;
    return r;
  }

  const mouse = { x: 0.5, y: 0.5 };
  const mouseTarget = { x: 0.5, y: 0.5 };
  if (cfg.enableMouseInteraction) {
    // Listens on window, not the canvas — this background sits behind page
    // content with pointer-events:none so clicks reach the UI above it,
    // which means the canvas itself never receives mouse events.
    window.addEventListener('mousemove', e => {
      const rect = canvas.getBoundingClientRect();
      mouseTarget.x = (e.clientX - rect.left) / (rect.width || 1);
      mouseTarget.y = 1 - (e.clientY - rect.top) / (rect.height || 1); // WebGL fragCoord.y is bottom-up
    }, { passive: true });
  }

  function resize() {
    canvas.width = canvas.offsetWidth;
    canvas.height = canvas.offsetHeight;
    rebuildBuffer();
  }
  resize();
  window.addEventListener('resize', resize);

  let elapsed = 0, lastTs = 0, skip = 0;

  function frame(ts) {
    if (!lastTs) lastTs = ts;
    const dt = (ts - lastTs) / 1000;
    lastTs = ts;
    elapsed += dt;

    if (cfg.enableMouseInteraction) {
      mouse.x += (mouseTarget.x - mouse.x) * 0.05;
      mouse.y += (mouseTarget.y - mouse.y) * 0.05;
    }

    skip++;
    if (skip >= 4) { // slow ambient field — recompute at ~15fps (buffer is bigger than the sibling effects', so this pays for it), upscale-draw every frame
      skip = 0;
      const halfT = elapsed * cfg.speed * 0.5;
      const fullT = elapsed * cfg.speed;
      const cycleT = fullT * cfg.colorCycleSpeed;
      const cosFullT = Math.cos(fullT), sinFullT = Math.sin(fullT);
      const [mrx, mry] = cfg.enableMouseInteraction ? rotate(mouse.x * 2 - 1, mouse.y * 2 - 1) : [0, 0];

      const d = img.data;
      for (let py = 0; py < bufH; py++) {
        const cy = (1 - py / bufH) * 2 - 1; // flip to match WebGL's bottom-up fragCoord.y
        for (let px = 0; px < bufW; px++) {
          const cx = (px / bufW) * 2 - 1;
          const [rx, ry] = rotate(cx, cy);

          let mouseWarp = 0;
          if (cfg.enableMouseInteraction) {
            const mdx = rx - mrx, mdy = ry - mry;
            mouseWarp = cfg.mouseInfluence * Math.exp(-(mdx * mdx + mdy * mdy) * 4);
          }

          const warpAx = rx + displaceA(ry, halfT) * cfg.warpIntensity + mouseWarp;
          const warpAy = ry - displaceA(rx * cosFullT * 1.235, halfT) * cfg.warpIntensity;
          const warpBx = rx + displaceB(ry, halfT) * cfg.warpIntensity + mouseWarp;
          const warpBy = ry - displaceB(rx * sinFullT * 1.235, halfT) * cfg.warpIntensity;

          // blended = mix(fieldA, fieldB, mix(fieldA, fieldB, 0.5)) — GLSL's vec2 mix
          // applies the third arg component-wise, so this resolves in closed form.
          const midX = (warpAx + warpBx) * 0.5, midY = (warpAy + warpBy) * 0.5;
          const blendedX = warpAx + (warpBx - warpAx) * midX;
          const blendedY = warpAy + (warpBy - warpAy) * midY;

          const fadeTop = smoothstep(cfg.edgeFadeWidth, cfg.edgeFadeWidth + 0.4, blendedY);
          const fadeBottom = smoothstep(-cfg.edgeFadeWidth, -(cfg.edgeFadeWidth + 0.4), blendedY);
          const vMask = 1 - Math.max(fadeTop, fadeBottom);

          const tileCount = cfg.outerLineCount + (cfg.innerLineCount - cfg.outerLineCount) * vMask;
          const scaledY = blendedY * tileCount;
          const nY = smoothNoise(Math.abs(scaledY));

          // pow(x, 5) with a possibly-negative base: JS's Math.pow (unlike GLSL's
          // exp2/log2-based pow) is exact for odd integer exponents, so this is
          // used as-is rather than the sign/abs split a literal GLSL port implies.
          const ridgeBase = (Math.abs(nY - blendedX) * 2 <= HALF_PI ? 1 : 0) * Math.cos(2 * (nY - blendedX));
          const ridge = Math.pow(ridgeBase, 5);

          const m = Math.max(frac(scaledY), frac(-scaledY));
          const lines = m * m + m * m * m * m; // pow(m,2) + pow(m,4)

          const pattern = vMask * lines;

          const rChannel = (pattern + lines * ridge) * (Math.cos(blendedY + cycleT * 0.234) * 0.5 + 1);
          const gChannel = (pattern + vMask * ridge) * (Math.sin(blendedX + cycleT * 1.745) * 0.5 + 1);
          const bChannel = (pattern + lines * ridge) * (Math.cos(blendedX + cycleT * 0.534) * 0.5 + 1);

          let colR = (rChannel * col1[0] + gChannel * col2[0] + bChannel * col3[0]) * cfg.brightness;
          let colG = (rChannel * col1[1] + gChannel * col2[1] + bChannel * col3[1]) * cfg.brightness;
          let colB = (rChannel * col1[2] + gChannel * col2[2] + bChannel * col3[2]) * cfg.brightness;

          // A hard clamp(length(col),0,1) here (the literal GLSL translation)
          // saturates to fully-opaque white the moment the three channels sum
          // past ~0.58, which — since the ridge term routinely spikes several
          // times past 1 — reads as stark binary black/white bands rather
          // than a soft wash. Soft-clip with an exponential instead so it
          // eases toward full intensity, same motion/pattern, no hard edge.
          const mag = Math.sqrt(colR * colR + colG * colG + colB * colB);
          const alpha = 1 - Math.exp(-mag * 1.1);
          if (mag > 0.0001) {
            const scale = alpha / mag;
            colR *= scale; colG *= scale; colB *= scale;
          }

          const i4 = (py * bufW + px) * 4;
          d[i4]     = Math.min(255, Math.max(0, colR * 255));
          d[i4 + 1] = Math.min(255, Math.max(0, colG * 255));
          d[i4 + 2] = Math.min(255, Math.max(0, colB * 255));
          d[i4 + 3] = alpha * 255;
        }
      }
      bctx.putImageData(img, 0, 0);
    }

    const w = canvas.width, h = canvas.height;
    ctx.clearRect(0, 0, w, h);
    ctx.imageSmoothingEnabled = true;
    ctx.imageSmoothingQuality = 'high';
    ctx.drawImage(buf, 0, 0, w, h);

    requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);
}
