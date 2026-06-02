'use strict';

class AudioSystem {
  constructor() {
    this.ctx = null;
    this.master = null;
    this.volume = 0.6;
    this.muted   = false;
    this._ambientStarted = false;
    this._footstepTimer  = 0;
    this._ambientNodes   = [];
  }

  _init() {
    if (this.ctx) return;
    this.ctx = new (window.AudioContext || window.webkitAudioContext)();
    this.master = this.ctx.createGain();
    this.master.gain.value = this.volume;
    this.master.connect(this.ctx.destination);
  }

  _resume() {
    if (this.ctx && this.ctx.state === 'suspended') this.ctx.resume();
  }

  setVolume(v) {
    this.volume = v;
    if (this.master) this.master.gain.setTargetAtTime(this.muted ? 0 : v, this.ctx.currentTime, 0.1);
  }

  setMuted(m) {
    this.muted = m;
    if (this.master) this.master.gain.setTargetAtTime(m ? 0 : this.volume, this.ctx.currentTime, 0.1);
  }

  _play(freq, type, duration, gain, startRamp = 0.01, endRamp = null) {
    if (!this.ctx || this.muted) return;
    endRamp = endRamp ?? duration;
    const t   = this.ctx.currentTime;
    const osc = this.ctx.createOscillator();
    const g   = this.ctx.createGain();
    osc.type  = type;
    osc.frequency.value = freq;
    osc.connect(g);
    g.connect(this.master);
    g.gain.setValueAtTime(0, t);
    g.gain.linearRampToValueAtTime(gain, t + startRamp);
    g.gain.linearRampToValueAtTime(0,    t + endRamp);
    osc.start(t);
    osc.stop(t + duration + 0.05);
  }

  _playNoise(duration, gain, filterFreq = 1000) {
    if (!this.ctx || this.muted) return;
    const t      = this.ctx.currentTime;
    const buf    = this.ctx.createBuffer(1, this.ctx.sampleRate * duration, this.ctx.sampleRate);
    const data   = buf.getChannelData(0);
    for (let i = 0; i < data.length; i++) data[i] = Math.random() * 2 - 1;
    const src    = this.ctx.createBufferSource();
    src.buffer   = buf;
    const filter = this.ctx.createBiquadFilter();
    filter.type  = 'bandpass';
    filter.frequency.value = filterFreq;
    const g      = this.ctx.createGain();
    src.connect(filter); filter.connect(g); g.connect(this.master);
    g.gain.setValueAtTime(gain, t);
    g.gain.linearRampToValueAtTime(0, t + duration);
    src.start(t); src.stop(t + duration + 0.05);
  }

  // ── Game sounds ──────────────────────────────────────────────────────────────
  playChop() {
    this._init(); this._resume();
    this._playNoise(0.12, 0.18, 800);
    this._play(200, 'square', 0.1, 0.08);
  }

  playMine() {
    this._init(); this._resume();
    this._playNoise(0.15, 0.2, 500);
    this._play(120, 'square', 0.12, 0.06);
  }

  playFootstep() {
    this._init(); this._resume();
    this._playNoise(0.06, 0.05, 300);
  }

  playHit() {
    this._init(); this._resume();
    this._play(150, 'sawtooth', 0.15, 0.15, 0.01, 0.12);
    this._playNoise(0.1, 0.1, 400);
  }

  playDeath() {
    this._init(); this._resume();
    [220, 180, 140, 110].forEach((f, i) => {
      setTimeout(() => this._play(f, 'sine', 0.4, 0.2, 0.01, 0.35), i * 180);
    });
  }

  playCraft() {
    this._init(); this._resume();
    [440, 550, 660].forEach((f, i) => {
      setTimeout(() => this._play(f, 'triangle', 0.2, 0.15, 0.01, 0.18), i * 80);
    });
  }

  playPickup() {
    this._init(); this._resume();
    this._play(880, 'sine', 0.12, 0.12, 0.005, 0.1);
  }

  playBuild() {
    this._init(); this._resume();
    this._playNoise(0.2, 0.15, 600);
    this._play(300, 'square', 0.15, 0.08);
  }

  playEat() {
    this._init(); this._resume();
    this._playNoise(0.08, 0.1, 1200);
  }

  playEnemyGrowl() {
    this._init(); this._resume();
    this._play(80, 'sawtooth', 0.3, 0.12);
  }

  // ── Ambient ──────────────────────────────────────────────────────────────────
  startDayAmbient() {
    this._init(); this._resume();
    if (this._ambientStarted) return;
    this._ambientStarted = true;
    this._scheduleAmbientChirp();
  }

  _scheduleAmbientChirp() {
    if (!this.ctx || this.muted) { setTimeout(() => this._scheduleAmbientChirp(), 3000); return; }
    const delay = 2000 + Math.random() * 5000;
    setTimeout(() => {
      if (!this.muted) {
        const freq = 800 + Math.random() * 400;
        this._play(freq,           'sine', 0.1, 0.06, 0.01, 0.08);
        this._play(freq * 1.25,    'sine', 0.1, 0.04, 0.05, 0.08);
      }
      this._scheduleAmbientChirp();
    }, delay);
  }

  // Called each frame when moving
  tickFootstep(dt, isMoving, isSprinting) {
    if (!isMoving) { this._footstepTimer = 0; return; }
    this._footstepTimer += dt;
    const interval = isSprinting ? 0.35 : 0.55;
    if (this._footstepTimer >= interval) {
      this._footstepTimer = 0;
      this.playFootstep();
    }
  }
}
