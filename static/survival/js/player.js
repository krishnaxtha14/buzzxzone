'use strict';

class PlayerSystem {
  constructor(game, camera) {
    this.game   = game;
    this.camera = camera;

    // Controls
    this.controls = new THREE.PointerLockControls(camera, document.body);
    game.scene.add(this.controls.getObject());
    this.mouseSensitivity = CONFIG.MOUSE_SENSITIVITY;

    // Replace PLControls' built-in 0.002 sensitivity with our configurable one.
    // In r128 the listener is on domElement.ownerDocument.
    const doc = document.body.ownerDocument;
    if (this.controls.onMouseMove) {
      doc.removeEventListener('mousemove', this.controls.onMouseMove, false);
    }
    this._onMouseMoveBound = e => this._onMouseMove(e);
    doc.addEventListener('mousemove', this._onMouseMoveBound, false);

    this.controls.addEventListener('lock',   () => { document.getElementById('click-to-play').classList.add('hidden'); });
    this.controls.addEventListener('unlock', () => {
      if (game.state === 'playing') document.getElementById('click-to-play').classList.remove('hidden');
    });

    // Movement state
    this.keys = {};
    this.mobileMode = false;  // set true by MobileControls
    this.velocity   = new THREE.Vector3();
    this.onGround   = false;
    this.isCrouching  = false;
    this.isSprinting  = false;

    // Gathering
    this.gatherProgress = 0;
    this.gatherTarget   = null;
    this.isGathering    = false;
    this.gatherKey      = false; // is gather key held

    // Stats
    this.health  = CONFIG.MAX_HEALTH;
    this.hunger  = CONFIG.MAX_HUNGER;
    this.thirst  = CONFIG.MAX_THIRST;
    this.stamina = CONFIG.MAX_STAMINA;
    this.xp      = 0;
    this.level   = 1;
    this.alive   = true;

    // Combat
    this.attackCooldown = 0;
    this.lastDamagedTime = 0;

    this.spawnPosition = new THREE.Vector3(0, 10, 0);

    // Raycaster for interactions
    this._raycaster = new THREE.Raycaster();
    this._center    = new THREE.Vector2(0, 0);
  }

  _onMouseMove(e) {
    if (!this.controls.isLocked) return;
    // In r128 PointerLockControls: getObject() = yawObject, yawObject.children[0] = pitchObject
    const yawObj   = this.controls.getObject();
    const pitchObj = yawObj.children[0];
    yawObj.rotation.y   -= e.movementX * this.mouseSensitivity;
    pitchObj.rotation.x -= e.movementY * this.mouseSensitivity;
    pitchObj.rotation.x  = Math.max(-Math.PI / 2 + 0.01, Math.min(Math.PI / 2 - 0.01, pitchObj.rotation.x));
  }

  onKeyDown(e) { this.keys[e.code] = true; }
  onKeyUp(e)   { this.keys[e.code] = false; }

  reset(pos) {
    this.health  = CONFIG.MAX_HEALTH;
    this.hunger  = CONFIG.MAX_HUNGER;
    this.thirst  = CONFIG.MAX_THIRST;
    this.stamina = CONFIG.MAX_STAMINA;
    this.xp      = 0;
    this.level   = 1;
    this.alive   = true;
    this.velocity.set(0, 0, 0);
    this.controls.getObject().position.copy(pos);
    // Reset camera orientation
    this.controls.getObject().rotation.y = 0;
    if (this.controls.getObject().children[0]) this.controls.getObject().children[0].rotation.x = 0;
    this.gatherTarget = null;
    this.gatherProgress = 0;
    this.isGathering = false;
  }

  loadState(data) {
    this.health  = data.health  ?? CONFIG.MAX_HEALTH;
    this.hunger  = data.hunger  ?? CONFIG.MAX_HUNGER;
    this.thirst  = data.thirst  ?? CONFIG.MAX_THIRST;
    this.stamina = data.stamina ?? CONFIG.MAX_STAMINA;
    this.xp      = data.xp     ?? 0;
    this.level   = data.level  ?? 1;
    if (data.position) this.controls.getObject().position.set(data.position.x, data.position.y, data.position.z);
    this.alive = true;
  }

  getPosition() { return this.controls.getObject().position; }

  addXP(amount) {
    this.xp += amount;
    const needed = this.level * CONFIG.XP_PER_LEVEL;
    if (this.xp >= needed) {
      this.xp -= needed;
      this.level++;
      this.game.ui.notify(`Level up! You are now level ${this.level}!`, 'success');
      this.health = Math.min(CONFIG.MAX_HEALTH, this.health + 20);
    }
  }

  takeDamage(amount, source = '') {
    if (!this.alive) return;
    this.health -= amount;
    this.lastDamagedTime = Date.now();
    this.game.audio._play(180, 'sawtooth', 0.1, 0.12);
    if (this.health <= 0) {
      this.health = 0;
      this.alive  = false;
      this.game.die(source);
    }
  }

  heal(amount) {
    this.health = Math.min(CONFIG.MAX_HEALTH, this.health + amount);
  }

  eatItem(item) {
    if (item.hungerRestore)  this.hunger  = Math.min(CONFIG.MAX_HUNGER,  this.hunger  + item.hungerRestore);
    if (item.thirstRestore)  this.thirst  = Math.min(CONFIG.MAX_THIRST,  this.thirst  + item.thirstRestore);
    if (item.healthRestore)  this.health  = Math.min(CONFIG.MAX_HEALTH,  this.health  + item.healthRestore);
    if (item.healthEffect)   this.health  = Math.max(1,                  this.health  + item.healthEffect);
    this.game.audio.playEat();
  }

  useHotbarItem() {
    const slot = this.game.inventory.hotbarSelected;
    const item = this.game.inventory.getHotbarItem(slot);
    if (!item) return;
    const def = ITEMS[item.id];
    if (!def) return;
    if (def.use === 'eat' || def.use === 'drink' || def.use === 'heal') {
      this.eatItem(def);
      this.game.inventory.consumeHotbarItem(slot, 1);
    } else if (def.placeable) {
      this.game.building.startPlacementFromItem(item.id);
    }
  }

  interact() {
    // F key — interact with nearest object (chest, campfire, etc.)
    const node = this.game.terrain.getNearestNode(this.getPosition(), 2.5);
    if (node && node.type === 'bush') {
      const loot = this.game.terrain.harvestNode(node, 20);
      if (loot) {
        for (const [id, qty] of Object.entries(loot)) {
          this.game.inventory.addItem(id, qty);
          this.game.ui.notify(`+${qty} ${ITEMS[id]?.name || id}`, 'info');
        }
        this.addXP(CONFIG.XP_GATHER);
      }
    }
  }

  reload() {
    // R key — placeholder for future bow reload
  }

  meleeAttack() {
    if (!this.alive || this.attackCooldown > 0) return;
    this.attackCooldown = CONFIG.ATTACK_COOLDOWN;

    // Get equipped weapon
    const slot   = this.game.inventory.hotbarSelected;
    const item   = this.game.inventory.getHotbarItem(slot);
    const def    = item ? ITEMS[item.id] : null;
    const baseDmg = def?.damage ?? 5;
    const isCrit  = Math.random() < CONFIG.CRIT_CHANCE;
    const damage  = isCrit ? baseDmg * CONFIG.CRIT_MULT : baseDmg;

    this.game.audio.playHit();
    if (isCrit) this.game.ui.notify('Critical hit!', 'warning');

    // Raycast for enemy hits
    this._raycaster.setFromCamera(this._center, this.camera);
    const enemies = this.game.enemies.getEnemyMeshes();
    const hits    = this._raycaster.intersectObjects(enemies, true);

    if (hits.length > 0 && hits[0].distance < CONFIG.MELEE_RANGE) {
      const enemy = hits[0].object.userData.enemy;
      if (enemy) {
        enemy.takeDamage(damage);
        this.game.ui.notify(`-${Math.round(damage)} ${isCrit ? '(CRIT)' : ''}`, 'warning');
      }
    }

    // Gather with tool on held E
    if (!this.isGathering) {
      const node = this.game.terrain.getNearestNode(this.getPosition(), CONFIG.GATHER_RANGE);
      if (node) {
        const canGather = (def?.gatherType === node.type) ||
                          (!def && (node.type === 'bush' || node.type === 'tree'));
        if (canGather) this._startGather(node);
      }
    }
  }

  _startGather(node) {
    this.isGathering    = true;
    this.gatherTarget   = node;
    this.gatherProgress = 0;
  }

  _cancelGather() {
    this.isGathering    = false;
    this.gatherTarget   = null;
    this.gatherProgress = 0;
    document.getElementById('action-prompt').classList.add('hidden');
  }

  update(dt) {
    if (!this.alive) return;
    this._updateMovement(dt);
    this._updateStats(dt);
    this._updateGathering(dt);
    this._updateAttackCooldown(dt);
    this._checkNearbyNodes();
    this.game.audio.tickFootstep(dt, this._isMoving(), this.isSprinting);
  }

  _isMoving() {
    return (this.keys['KeyW'] || this.keys['KeyS'] || this.keys['KeyA'] || this.keys['KeyD']) &&
           this.controls.isLocked;
  }

  _updateMovement(dt) {
    if (!this.controls.isLocked && !this.mobileMode) return;

    this.isSprinting = this.keys['ShiftLeft'] && this.stamina > 5 && !this.isCrouching;
    this.isCrouching = this.keys['ControlLeft'] || this.keys['KeyC'];

    const speed = this.isCrouching ? CONFIG.CROUCH_SPEED
                : this.isSprinting ? CONFIG.SPRINT_SPEED
                : CONFIG.MOVE_SPEED;

    // Stamina
    if (this.isSprinting && this._isMoving()) {
      this.stamina = Math.max(0, this.stamina - CONFIG.STAMINA_DRAIN * dt);
    } else {
      this.stamina = Math.min(CONFIG.MAX_STAMINA, this.stamina + CONFIG.STAMINA_REGEN * dt);
    }

    // Horizontal velocity from keys
    const dir = new THREE.Vector3();
    if (this.keys['KeyW']) dir.z -= 1;
    if (this.keys['KeyS']) dir.z += 1;
    if (this.keys['KeyA']) dir.x -= 1;
    if (this.keys['KeyD']) dir.x += 1;
    dir.normalize();

    const obj      = this.controls.getObject();
    const forward  = new THREE.Vector3();
    const right    = new THREE.Vector3();
    obj.getWorldDirection(forward);
    forward.y = 0; forward.normalize();
    right.crossVectors(forward, new THREE.Vector3(0, 1, 0));

    const move = new THREE.Vector3();
    move.addScaledVector(forward, -dir.z);
    move.addScaledVector(right, dir.x);
    move.normalize().multiplyScalar(speed);

    this.velocity.x = move.x;
    this.velocity.z = move.z;

    // Jump
    if (this.keys['Space'] && this.onGround) {
      this.velocity.y = CONFIG.JUMP_FORCE;
      this.onGround = false;
    }

    // Gravity
    this.velocity.y += CONFIG.GRAVITY * dt;

    // Apply
    obj.position.x += this.velocity.x * dt;
    obj.position.z += this.velocity.z * dt;
    obj.position.y += this.velocity.y * dt;

    // Ground collision
    const gH = this.game.terrain.getGroundHeight(obj.position.x, obj.position.z);
    const minY = gH + (this.isCrouching ? CONFIG.PLAYER_HEIGHT * 0.7 : CONFIG.PLAYER_HEIGHT);
    if (obj.position.y < minY) {
      obj.position.y = minY;
      this.velocity.y = 0;
      this.onGround = true;
    } else if (obj.position.y > minY + 0.05) {
      this.onGround = false;
    }

    // Left-click = single attack per press (handled via mousedown listener)
  }

  _updateStats(dt) {
    // Drain
    this.hunger  = Math.max(0, this.hunger - CONFIG.HUNGER_DRAIN * dt);
    this.thirst  = Math.max(0, this.thirst - CONFIG.THIRST_DRAIN * dt);

    // Damage from starvation/dehydration
    if (this.hunger <= 0) this.takeDamage(CONFIG.HUNGER_DAMAGE * dt, 'starvation');
    if (this.thirst <= 0) this.takeDamage(CONFIG.THIRST_DAMAGE * dt, 'dehydration');

    // Passive health regen when well-fed/hydrated
    if (this.hunger > 60 && this.thirst > 60 && this.health < CONFIG.MAX_HEALTH) {
      this.health = Math.min(CONFIG.MAX_HEALTH, this.health + CONFIG.HEALTH_REGEN * dt);
    }
  }

  _updateGathering(dt) {
    const prompt = document.getElementById('action-prompt');
    const bar    = document.getElementById('action-bar-fill');
    const text   = document.getElementById('action-text');

    if (!this.isGathering || !this.gatherTarget) {
      if (!prompt.classList.contains('hidden')) prompt.classList.add('hidden');
      return;
    }

    // Check if still in range
    const pos  = this.getPosition();
    const dx   = this.gatherTarget.position.x - pos.x;
    const dz   = this.gatherTarget.position.z - pos.z;
    if (Math.sqrt(dx * dx + dz * dz) > CONFIG.GATHER_RANGE) {
      this._cancelGather(); return;
    }

    if (this.gatherTarget.depleted) { this._cancelGather(); return; }

    // Find equipped tool
    const item   = this.game.inventory.getHotbarItem(this.game.inventory.hotbarSelected);
    const def    = item ? ITEMS[item.id] : null;
    const isRight = def?.gatherType === this.gatherTarget.type;
    const speed  = isRight ? 33 : 20; // % per second
    this.gatherProgress += speed * dt;

    // Play sound
    if (Math.floor(this.gatherProgress / 30) !== Math.floor((this.gatherProgress - speed * dt) / 30)) {
      if (this.gatherTarget.type === 'tree') this.game.audio.playChop();
      else this.game.audio.playMine();
    }

    // Show progress bar
    prompt.classList.remove('hidden');
    bar.style.width  = Math.min(100, this.gatherProgress) + '%';
    const typeLabel  = this.gatherTarget.type === 'tree' ? 'Chopping tree' : 'Mining rock';
    text.textContent = `${typeLabel}... ${Math.floor(this.gatherProgress)}%`;

    if (this.gatherProgress >= 100) {
      this.gatherProgress = 0;
      const loot = this.game.terrain.harvestNode(this.gatherTarget, 100);
      if (loot) {
        for (const [id, qty] of Object.entries(loot)) {
          this.game.inventory.addItem(id, qty);
          this.game.ui.notify(`+${qty} ${ITEMS[id]?.name || id}`, 'info');
        }
        this.addXP(CONFIG.XP_GATHER);
        this._cancelGather();
      }
    }
  }

  _updateAttackCooldown(dt) {
    if (this.attackCooldown > 0) this.attackCooldown -= dt;
  }

  _checkNearbyNodes() {
    // Show gathering prompt when looking at / near gatherable node
    const node = this.game.terrain.getNearestNode(this.getPosition(), CONFIG.GATHER_RANGE);
    if (node && !this.isGathering) {
      const prompt = document.getElementById('action-prompt');
      const text   = document.getElementById('action-text');
      prompt.classList.remove('hidden');
      document.getElementById('action-bar-fill').style.width = '0%';
      const label  = node.type === 'tree' ? '🌲 Hold [E] to chop tree'
                   : node.type === 'rock' ? '🪨 Hold [E] to mine rock'
                   : '🌿 Press [F] to gather';
      text.textContent = label;
    }
  }

  getState() {
    const pos = this.getPosition();
    return {
      health:   this.health,
      hunger:   this.hunger,
      thirst:   this.thirst,
      stamina:  this.stamina,
      xp:       this.xp,
      level:    this.level,
      position: { x: pos.x, y: pos.y, z: pos.z },
    };
  }
}

// Left-click = single attack; hold = continuous gather
document.addEventListener('mousedown', e => {
  if (e.button === 0 && window.GAME?.state === 'playing' && window.GAME.player.controls.isLocked) {
    window.GAME.player.meleeAttack();
    window.GAME.player.keys['MouseLeft'] = true;
  }
});
document.addEventListener('mouseup', e => {
  if (e.button === 0 && window.GAME?.player) {
    window.GAME.player.keys['MouseLeft'] = false;
    if (window.GAME.player.isGathering) window.GAME.player._cancelGather();
  }
});
