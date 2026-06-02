'use strict';

class MobileControls {
  constructor(game) {
    this.game = game;
    this.active = this._detect();

    if (!this.active) return;

    // Flag the player system so it skips pointer-lock check
    game.player.mobileMode = true;

    document.getElementById('mobile-ui').classList.remove('hidden');
    document.getElementById('click-to-play').classList.add('hidden'); // never shown on mobile

    this._joyOrigin  = { x: 0, y: 0 };
    this._joyDelta   = { x: 0, y: 0 };
    this._joyTouchId = null;
    this._camTouchId = null;
    this._camLastX   = 0;
    this._camLastY   = 0;
    this._joyActive  = false;

    this._setupJoystick();
    this._setupCamera();
    this._setupButtons();
    this._setupGestures();
  }

  _detect() {
    return /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent)
      || ('ontouchstart' in window && navigator.maxTouchPoints > 1);
  }

  // ── Virtual joystick ────────────────────────────────────────────────────────
  _setupJoystick() {
    const zone  = document.getElementById('joy-zone');
    const base  = document.getElementById('joy-base');
    const thumb = document.getElementById('joy-thumb');

    const start = (cx, cy, id) => {
      this._joyTouchId = id;
      this._joyActive  = true;
      this._joyOrigin  = { x: cx, y: cy };
      base.style.left    = (cx - 55) + 'px';
      base.style.top     = (cy - 55) + 'px';
      base.style.opacity = '1';
    };

    const move = (cx, cy) => {
      if (!this._joyActive) return;
      const dx    = cx - this._joyOrigin.x;
      const dy    = cy - this._joyOrigin.y;
      const dist  = Math.sqrt(dx * dx + dy * dy);
      const max   = 52;
      const angle = Math.atan2(dy, dx);
      const cDist = Math.min(dist, max);
      this._joyDelta.x = Math.cos(angle) * (cDist / max);
      this._joyDelta.y = Math.sin(angle) * (cDist / max);
      thumb.style.transform = `translate(${Math.cos(angle) * cDist}px,${Math.sin(angle) * cDist}px)`;
    };

    const end = () => {
      this._joyActive   = false;
      this._joyTouchId  = null;
      this._joyDelta    = { x: 0, y: 0 };
      thumb.style.transform = 'translate(0,0)';
      base.style.opacity = '0.7';
    };

    zone.addEventListener('touchstart', e => {
      e.preventDefault();
      const t = e.changedTouches[0];
      start(t.clientX, t.clientY, t.identifier);
    }, { passive: false });

    zone.addEventListener('touchmove', e => {
      e.preventDefault();
      for (const t of e.changedTouches) {
        if (t.identifier === this._joyTouchId) move(t.clientX, t.clientY);
      }
    }, { passive: false });

    zone.addEventListener('touchend',    () => end());
    zone.addEventListener('touchcancel', () => end());
  }

  // ── Camera swipe (right half of screen) ────────────────────────────────────
  _setupCamera() {
    const zone = document.getElementById('cam-zone');

    zone.addEventListener('touchstart', e => {
      e.preventDefault();
      for (const t of e.changedTouches) {
        if (this._camTouchId === null) {
          this._camTouchId = t.identifier;
          this._camLastX   = t.clientX;
          this._camLastY   = t.clientY;
        }
      }
    }, { passive: false });

    zone.addEventListener('touchmove', e => {
      e.preventDefault();
      for (const t of e.changedTouches) {
        if (t.identifier !== this._camTouchId) continue;
        const dx = t.clientX - this._camLastX;
        const dy = t.clientY - this._camLastY;
        this._camLastX = t.clientX;
        this._camLastY = t.clientY;
        if (this.game.state === 'playing' && this.game.player) {
          // Inject as synthetic mouse movement
          this.game.player._onMouseMove({ movementX: dx * 1.5, movementY: dy * 1.5 });
        }
      }
    }, { passive: false });

    zone.addEventListener('touchend', e => {
      for (const t of e.changedTouches) {
        if (t.identifier === this._camTouchId) this._camTouchId = null;
      }
    });

    // Tap on camera zone = attack
    zone.addEventListener('click', () => {
      if (this.game.state === 'playing' && this.game.player) this.game.player.meleeAttack();
    });
  }

  // ── Action buttons ──────────────────────────────────────────────────────────
  _setupButtons() {
    const btn = (id, action) => {
      const el = document.getElementById(id);
      if (!el) return;
      el.addEventListener('touchstart', e => { e.preventDefault(); action('down'); }, { passive: false });
      el.addEventListener('touchend',   e => { e.preventDefault(); action('up');   }, { passive: false });
    };

    btn('mob-jump',   dir => { if (this.game.player) this.game.player.keys['Space']      = dir === 'down'; });
    btn('mob-sprint', dir => { if (this.game.player) this.game.player.keys['ShiftLeft']  = dir === 'down'; });
    btn('mob-crouch', dir => { if (this.game.player) this.game.player.keys['ControlLeft']= dir === 'down'; });

    const attackEl = document.getElementById('mob-attack');
    if (attackEl) {
      attackEl.addEventListener('touchstart', e => {
        e.preventDefault();
        if (this.game.player) this.game.player.meleeAttack();
      }, { passive: false });
    }

    const gatherEl = document.getElementById('mob-gather');
    if (gatherEl) {
      gatherEl.addEventListener('touchstart', e => {
        e.preventDefault();
        const p = this.game.player;
        if (!p) return;
        const node = this.game.terrain.getNearestNode(p.getPosition(), CONFIG.GATHER_RANGE);
        if (node) p._startGather(node);
        else p.useHotbarItem();
      }, { passive: false });
      gatherEl.addEventListener('touchend', () => {
        if (this.game.player?.isGathering) this.game.player._cancelGather();
      });
    }

    // Menu button (ESC equivalent)
    const menuEl = document.getElementById('mob-menu');
    if (menuEl) {
      menuEl.addEventListener('touchstart', e => {
        e.preventDefault();
        if (this.game.state === 'playing') this.game.pause();
        else if (this.game.state === 'paused') this.game.resume();
      }, { passive: false });
    }

    // Inventory shortcut
    const invEl = document.getElementById('mob-inv');
    if (invEl) {
      invEl.addEventListener('touchstart', e => {
        e.preventDefault();
        if (this.game.inventory.isOpen()) this.game.inventory.close();
        else this.game.inventory.open();
      }, { passive: false });
    }
  }

  // ── Prevent browser default pinch/zoom ─────────────────────────────────────
  _setupGestures() {
    document.addEventListener('gesturestart',  e => e.preventDefault(), { passive: false });
    document.addEventListener('gesturechange', e => e.preventDefault(), { passive: false });
    document.addEventListener('touchmove', e => {
      if (e.touches.length > 1) e.preventDefault();
    }, { passive: false });
  }

  // ── Update: pump joystick into player keys ──────────────────────────────────
  update() {
    if (!this.active || !this.game.player) return;
    const p  = this.game.player;
    const dx = this._joyDelta.x;
    const dy = this._joyDelta.y;
    p.keys['KeyW'] = dy < -0.25;
    p.keys['KeyS'] = dy >  0.25;
    p.keys['KeyA'] = dx < -0.25;
    p.keys['KeyD'] = dx >  0.25;
  }

  // ── Scale HUD for mobile ────────────────────────────────────────────────────
  scaleHUD() {
    if (!this.active) return;
    document.getElementById('hotbar').style.bottom   = '170px';
    document.getElementById('stat-bars').style.top   = '8px';
    document.getElementById('stat-bars').style.left  = '8px';
    document.getElementById('minimap-wrap').style.top = '8px';
    document.getElementById('minimap-wrap').style.right = '8px';
  }
}
