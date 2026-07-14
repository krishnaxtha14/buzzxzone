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
  el.textContent = '';
  const isVertical = cfg.direction === 'up' || cfg.direction === 'down';
  const reverse = cfg.direction === 'left' || cfg.direction === 'up';

  const entries = text.split('').map(ch => {
    const wrap = document.createElement('span');
    wrap.style.cssText = 'display:inline-block; overflow:hidden; vertical-align:bottom;';
    const strip = document.createElement('span');
    strip.style.cssText = 'display:block; will-change:transform;';
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
      const offset = reverse ? -cfg.shuffleTimes * size : -cfg.shuffleTimes * size;
      strip.style.transition = 'none';
      strip.style.transform = isVertical
        ? `translateY(${reverse ? 0 : offset}px)`
        : `translateX(${reverse ? 0 : offset}px)`;
      if (reverse) strip.dataset.restTransform = isVertical ? `translateY(${offset}px)` : `translateX(${offset}px)`;
      else strip.dataset.restTransform = isVertical ? 'translateY(0)' : 'translateX(0)';
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
