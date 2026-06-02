'use strict';

class Game {
  constructor() {
    this.state        = 'loading';
    this.clock        = new THREE.Clock();
    this.dt           = 0;
    this.frameCount   = 0;
    this.totalTime    = 0;
    this.survivalTime = 0;
    this.dayNumber    = 1;

    // Systems
    this.scene       = null;
    this.camera      = null;
    this.renderer    = null;
    this.terrain     = null;
    this.player      = null;
    this.inventory   = null;
    this.crafting    = null;
    this.building    = null;
    this.enemies     = null;
    this.environment = null;
    this.audio       = null;
    this.ui          = null;
    this.save        = null;
  }

  async init() {
    this._setupRenderer();
    this._setupScene();
    await this._loadRecipes();
    this._setupSystems();
    this._setupEvents();
    await this._generateWorld();
    document.getElementById('loading-screen').classList.add('hidden');
    document.getElementById('main-menu').classList.remove('hidden');
    this.state = 'menu';
    this._loop();
  }

  _setupRenderer() {
    const canvas    = document.getElementById('game-canvas');
    this.renderer   = new THREE.WebGLRenderer({ canvas, antialias: true, powerPreference: 'high-performance' });
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    this.renderer.setSize(window.innerWidth, window.innerHeight);
    this.renderer.shadowMap.enabled = true;
    this.renderer.shadowMap.type    = THREE.PCFSoftShadowMap;
    this.renderer.setClearColor(0x87ceeb, 1);   // sky blue default
    window.addEventListener('resize', () => {
      this.camera.aspect = window.innerWidth / window.innerHeight;
      this.camera.updateProjectionMatrix();
      this.renderer.setSize(window.innerWidth, window.innerHeight);
    });
  }

  _setupScene() {
    this.scene     = new THREE.Scene();
    this.scene.fog = new THREE.Fog(0x87ceeb, 60, 200);
    this.camera    = new THREE.PerspectiveCamera(75, window.innerWidth / window.innerHeight, 0.1, 500);
    // Keep camera above ground during menu/load state
    this.camera.position.set(0, 30, 0);
  }

  async _loadRecipes() {
    try {
      const r     = await fetch('/static/survival/data/recipes.json');
      this.recipes = await r.json();
    } catch (e) { this.recipes = []; }
  }

  _setupSystems() {
    const noise    = new SimplexNoise(CONFIG.SEED);
    this.audio     = new AudioSystem();
    this.terrain   = new TerrainSystem(this.scene, noise);
    this.player    = new PlayerSystem(this, this.camera);
    this.inventory = new InventorySystem(this);
    this.crafting  = new CraftingSystem(this, this.recipes);
    this.building  = new BuildingSystem(this);
    this.enemies   = new EnemySystem(this);
    this.environment = new EnvironmentSystem(this);
    this.ui        = new UISystem(this);
    this.save      = new SaveSystem(this);
    window.GAME    = this;
  }

  async _generateWorld() {
    const prog = document.getElementById('loading-progress');
    const txt  = document.getElementById('loading-text');

    txt.textContent  = 'Generating terrain...';
    prog.style.width = '15%';
    await this._tick(80);

    this.terrain.loadChunksAround(0, 0, CONFIG.RENDER_DISTANCE);
    prog.style.width = '55%';
    txt.textContent  = 'Placing resources...';
    await this._tick(100);

    const spawnH = this.terrain.getGroundHeight(0, 0) + CONFIG.PLAYER_HEIGHT + 0.5;
    this.player.spawnPosition = new THREE.Vector3(0, Math.max(spawnH, 6), 0);

    prog.style.width = '75%';
    txt.textContent  = 'Spawning wildlife...';
    await this._tick(80);

    this.enemies.initialSpawn();

    prog.style.width = '95%';
    txt.textContent  = 'Almost ready...';
    await this._tick(400);
    prog.style.width = '100%';
  }

  _tick(ms) { return new Promise(r => setTimeout(r, ms)); }

  // ── Game state transitions ────────────────────────────────────────────────────
  newGame() {
    document.getElementById('main-menu').classList.add('hidden');
    document.getElementById('hud').classList.remove('hidden');

    this.dayNumber    = 1;
    this.survivalTime = 0;

    this.inventory.reset();
    this.inventory.addItem('wood',          10);
    this.inventory.addItem('stone',          5);
    this.inventory.addItem('stick',          8);
    this.inventory.addItem('wooden_axe',     1);
    this.inventory.addItem('wooden_pickaxe', 1);
    this.inventory.addItem('berries',        4);
    this.inventory.addItem('bandage',        2);

    this.player.reset(this.player.spawnPosition.clone());
    this.environment.setTime(360);
    this.state = 'playing';
    this.audio.startDayAmbient();
    this.player.controls.lock();
    this.ui.notify('Welcome to Survival Craft! Gather resources to survive.', 'info', 5000);
  }

  pause() {
    if (this.state !== 'playing') return;
    this.state = 'paused';
    this.player.controls.unlock();
    document.getElementById('pause-menu').classList.remove('hidden');
    document.getElementById('click-to-play').classList.add('hidden');
  }

  resume() {
    if (this.state !== 'paused') return;
    document.getElementById('pause-menu').classList.add('hidden');
    this.state = 'playing';
    this.player.controls.lock();
  }

  die(cause = '') {
    if (this.state === 'dead') return;
    this.state = 'dead';
    this.player.controls.unlock();
    const ds = document.getElementById('death-screen');
    ds.classList.remove('hidden');
    const mins = Math.floor(this.survivalTime / 60);
    const secs = Math.floor(this.survivalTime % 60);
    document.getElementById('death-time').textContent = `${mins}:${String(secs).padStart(2,'0')}`;
    const causeEl = document.getElementById('death-cause');
    if (causeEl) causeEl.textContent = cause ? `Cause: ${cause}` : 'You succumbed to the wilderness.';
    this.audio.playDeath();
  }

  respawn() {
    document.getElementById('death-screen').classList.add('hidden');
    const h = this.terrain.getGroundHeight(0, 0) + CONFIG.PLAYER_HEIGHT + 0.5;
    this.player.reset(new THREE.Vector3(0, Math.max(h, 6), 0));
    this.inventory.dropHalf();
    this.state = 'playing';
    this.player.controls.lock();
    this.ui.notify('You respawned — half your items were lost.', 'warning');
  }

  async loadSavedGame() {
    const data = await this.save.loadGame();
    if (!data) { this.ui.notify('No saved game found.', 'error'); return; }

    document.getElementById('main-menu').classList.add('hidden');
    document.getElementById('hud').classList.remove('hidden');

    this.player.loadState(data.player);
    this.inventory.loadState(data.inventory);
    this.environment.setTime(data.environment?.time ?? 360);
    this.dayNumber    = data.dayNumber    ?? 1;
    this.survivalTime = data.survivalTime ?? 0;
    if (data.structures) this.building.loadStructures(data.structures);

    this.state = 'playing';
    this.audio.startDayAmbient();
    this.player.controls.lock();
    this.ui.notify('Game loaded!', 'success');
  }

  // ── Event wiring ──────────────────────────────────────────────────────────────
  _setupEvents() {
    document.getElementById('btn-new-game').addEventListener('click',       () => this.newGame());
    document.getElementById('btn-load-game').addEventListener('click',      () => this.loadSavedGame());
    document.getElementById('btn-resume').addEventListener('click',         () => this.resume());
    document.getElementById('btn-save').addEventListener('click',           () => this.save.saveGame(false));
    document.getElementById('btn-respawn').addEventListener('click',        () => this.respawn());
    document.getElementById('btn-close-inv').addEventListener('click',      () => this.inventory.close());
    document.getElementById('btn-close-craft').addEventListener('click',    () => this.crafting.close());
    document.getElementById('btn-close-build').addEventListener('click',    () => this.building.close());
    document.getElementById('btn-craft').addEventListener('click',          () => this.crafting.craftSelected());

    document.getElementById('btn-settings').addEventListener('click',       () => this._showSettings('main'));
    document.getElementById('btn-settings-pause').addEventListener('click', () => this._showSettings('pause'));
    document.getElementById('btn-settings-back').addEventListener('click',  () => this._hideSettings());

    const sensEl = document.getElementById('sensitivity-slider');
    if (sensEl) sensEl.addEventListener('input', e => {
      this.player.mouseSensitivity = parseFloat(e.target.value);
      document.getElementById('sensitivity-val').textContent = e.target.value;
    });

    const volEl = document.getElementById('volume-slider');
    if (volEl) volEl.addEventListener('input', e => {
      this.audio.setVolume(parseFloat(e.target.value));
      document.getElementById('volume-val').textContent = e.target.value;
    });

    const rdEl = document.getElementById('render-distance');
    if (rdEl) rdEl.addEventListener('change', e => { CONFIG.RENDER_DISTANCE = parseInt(e.target.value); });

    document.addEventListener('keydown', e => this._onKey(e));
    document.addEventListener('keyup',   e => { if (this.player) this.player.onKeyUp(e); });

    // Click-to-play overlay
    document.getElementById('click-to-play').addEventListener('click', () => {
      if (this.state === 'playing') this.player.controls.lock();
    });

    // Right-click cancels building
    document.addEventListener('contextmenu', e => {
      e.preventDefault();
      if (this.building._placing) this.building.cancelPlacement();
    });
  }

  _onKey(e) {
    if (this.player) this.player.onKeyDown(e);

    if (e.code === 'Escape') {
      if      (this.state === 'playing') this.pause();
      else if (this.state === 'paused')  this.resume();
      if (this.inventory.isOpen()) this.inventory.close();
      if (this.crafting.isOpen())  this.crafting.close();
      if (this.building.isOpen())  this.building.close();
      if (this.building._placing)  this.building.cancelPlacement();
      return;
    }

    if (this.state !== 'playing') return;

    const numKey = parseInt(e.key);
    if (numKey >= 1 && numKey <= 9) { this.inventory.selectHotbar(numKey - 1); return; }

    switch (e.code) {
      case 'KeyI':
        if (this.inventory.isOpen()) this.inventory.close();
        else { this.player.controls.unlock(); this.inventory.open(); }
        break;
      case 'KeyC':
        if (this.crafting.isOpen()) this.crafting.close();
        else { this.player.controls.unlock(); this.crafting.open(); }
        break;
      case 'KeyB':
        if (this.building.isOpen()) this.building.close();
        else { this.player.controls.unlock(); this.building.open(); }
        break;
      case 'KeyE':
        this.player.keys['KeyE'] = true;
        if (!this.player.isGathering) {
          const node = this.terrain.getNearestNode(this.player.getPosition(), CONFIG.GATHER_RANGE);
          if (node) this.player._startGather(node);
          else this.player.useHotbarItem();
        }
        break;
      case 'KeyF':
        this.player.interact();
        break;
      case 'KeyM':
        // Toggle mute
        this.audio.setMuted(!this.audio.muted);
        break;
    }
  }

  _showSettings(from) {
    this._settingsFrom = from;
    document.getElementById(from === 'main' ? 'main-menu' : 'pause-menu').classList.add('hidden');
    document.getElementById('settings-menu').classList.remove('hidden');
  }

  _hideSettings() {
    document.getElementById('settings-menu').classList.add('hidden');
    document.getElementById(this._settingsFrom === 'main' ? 'main-menu' : 'pause-menu').classList.remove('hidden');
  }

  // ── Main loop ────────────────────────────────────────────────────────────────
  _loop() {
    requestAnimationFrame(() => this._loop());

    this.dt = Math.min(this.clock.getDelta(), 0.05);
    this.frameCount++;

    if (this.state === 'playing') {
      this.totalTime    += this.dt;
      this.survivalTime += this.dt;
      this._update(this.dt);
    }

    this.renderer.render(this.scene, this.camera);
  }

  _update(dt) {
    const pos = this.player.getPosition();
    const cx  = Math.floor(pos.x / CONFIG.CHUNK_SIZE);
    const cz  = Math.floor(pos.z / CONFIG.CHUNK_SIZE);

    this.terrain.loadChunksAround(cx, cz, CONFIG.RENDER_DISTANCE);
    this.terrain.update(dt);
    this.player.update(dt);
    this.enemies.update(dt);
    this.environment.update(dt);
    this.building.update(dt);
    this.ui.update(dt);

    // Autosave every 5 min
    if (this.totalTime > 0 && Math.floor(this.totalTime) % CONFIG.AUTOSAVE_INTERVAL === 0 &&
        Math.floor(this.totalTime) !== this._lastAutosave) {
      this._lastAutosave = Math.floor(this.totalTime);
      this.save.saveGame(true);
    }
  }
}

// Boot
document.addEventListener('DOMContentLoaded', () => {
  const game = new Game();
  game.init().catch(err => {
    console.error('Boot error:', err);
    const lt = document.getElementById('loading-text');
    if (lt) lt.textContent = 'Error: ' + err.message;
  });
});
