'use strict';

class UISystem {
  constructor(game) {
    this.game = game;
    this._notifQueue = [];
    this._minimapCtx = null;
    this._fpsFrames  = 0;
    this._fpsTimer   = 0;
    this._fps        = 60;

    const mc = document.getElementById('minimap-canvas');
    if (mc) this._minimapCtx = mc.getContext('2d');
  }

  notify(msg, type = 'info', duration = 3000) {
    const el = document.createElement('div');
    el.className = `notif notif-${type}`;
    el.textContent = msg;
    document.getElementById('notif-container').appendChild(el);
    setTimeout(() => el.remove(), duration + 500);
  }

  update(dt) {
    if (this.game.state !== 'playing') return;

    this._fpsFrames++;
    this._fpsTimer += dt;
    if (this._fpsTimer >= 0.5) {
      this._fps = Math.round(this._fpsFrames / this._fpsTimer);
      this._fpsFrames = 0;
      this._fpsTimer  = 0;
    }

    this._updateBars();
    this._updateMinimap();
    this._updateDebug();
  }

  _updateBars() {
    const p = this.game.player;
    const set = (id, val, max) => {
      const pct = Math.max(0, Math.min(100, val / max * 100));
      const bar = document.getElementById(`bar-${id}`);
      const txt = document.getElementById(`txt-${id}`);
      if (bar) bar.style.width = pct + '%';
      if (txt) txt.textContent = Math.floor(val);

      // Color shift when critical
      if (bar && pct < 25) {
        bar.style.filter = 'brightness(1.5) saturate(1.5)';
      } else if (bar) {
        bar.style.filter = '';
      }
    };

    set('health',  p.health,  CONFIG.MAX_HEALTH);
    set('hunger',  p.hunger,  CONFIG.MAX_HUNGER);
    set('thirst',  p.thirst,  CONFIG.MAX_THIRST);
    set('stamina', p.stamina, CONFIG.MAX_STAMINA);

    // XP bar
    const xpBar  = document.getElementById('bar-xp');
    const lvlEl  = document.getElementById('level-display');
    const needed = p.level * CONFIG.XP_PER_LEVEL;
    if (xpBar) xpBar.style.width = Math.min(100, p.xp / needed * 100) + '%';
    if (lvlEl) lvlEl.textContent = `LVL ${p.level}`;
  }

  _updateMinimap() {
    const ctx = this._minimapCtx;
    if (!ctx) return;
    const W = 130, H = 130, R = 60;
    ctx.clearRect(0, 0, W, H);

    // Circle clip
    ctx.save();
    ctx.beginPath();
    ctx.arc(W/2, H/2, R, 0, Math.PI * 2);
    ctx.clip();

    // Background
    ctx.fillStyle = '#0d1a0d';
    ctx.fillRect(0, 0, W, H);

    const pos   = this.game.player.getPosition();
    const scale = 1.8;   // world units per pixel
    const ox    = W / 2, oy = H / 2;

    // Draw terrain color hints
    const { terrain } = this.game;
    for (let px = 0; px < W; px += 3) {
      for (let py = 0; py < H; py += 3) {
        const wx = pos.x + (px - ox) * scale;
        const wz = pos.z + (py - oy) * scale;
        const h  = terrain.getGroundHeight(wx, wz);
        const bio = terrain.getBiome(h, wx, wz);
        ctx.fillStyle = this._biomeColorCSS(bio);
        ctx.fillRect(px, py, 3, 3);
      }
    }

    // Draw structures
    for (const s of this.game.building.getStructures()) {
      const sx = ox + (s.position.x - pos.x) / scale;
      const sy = oy + (s.position.z - pos.z) / scale;
      ctx.fillStyle = '#a0522d';
      ctx.fillRect(sx - 2, sy - 2, 4, 4);
    }

    // Draw enemies
    for (const e of this.game.enemies.enemies) {
      if (e.isDead()) continue;
      const ex = ox + (e.position.x - pos.x) / scale;
      const ey = oy + (e.position.z - pos.z) / scale;
      ctx.fillStyle = e.type === 'wolf' || e.type === 'zombie' ? '#ff4444' : '#ffaa44';
      ctx.beginPath();
      ctx.arc(ex, ey, 2, 0, Math.PI * 2);
      ctx.fill();
    }

    // Player dot + direction
    ctx.fillStyle = '#ffffff';
    ctx.beginPath();
    ctx.arc(ox, oy, 3.5, 0, Math.PI * 2);
    ctx.fill();

    const yaw = this.game.player.controls.getObject().rotation.y;
    ctx.strokeStyle = '#4caf50';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(ox, oy);
    ctx.lineTo(ox + Math.sin(yaw) * 8, oy - Math.cos(yaw) * 8);
    ctx.stroke();

    ctx.restore();

    // Compass ring
    ctx.strokeStyle = 'rgba(76,175,80,0.4)';
    ctx.lineWidth   = 1.5;
    ctx.beginPath();
    ctx.arc(W/2, H/2, R, 0, Math.PI * 2);
    ctx.stroke();
  }

  _biomeColorCSS(biome) {
    switch (biome) {
      case 'water':     return '#1a5c99';
      case 'beach':     return '#c8a45e';
      case 'grassland': return '#2d7a2d';
      case 'forest':    return '#1a4d1a';
      case 'highland':  return '#6b6050';
      case 'mountain':  return '#888888';
      default:          return '#2d5016';
    }
  }

  _updateDebug() {
    const pos   = this.game.player.getPosition();
    const posEl = document.getElementById('pos-display');
    const fpsEl = document.getElementById('fps-display');
    if (posEl) posEl.textContent = `${pos.x.toFixed(0)}, ${pos.y.toFixed(0)}, ${pos.z.toFixed(0)}`;
    if (fpsEl) fpsEl.textContent = `${this._fps} FPS`;
  }
}
