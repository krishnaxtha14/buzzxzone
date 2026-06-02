'use strict';

// ── Enemy States ────────────────────────────────────────────────────────────────
const EState = { IDLE: 0, PATROL: 1, CHASE: 2, ATTACK: 3, FLEE: 4, DEAD: 5 };

class Enemy {
  constructor(scene, type, position) {
    this.scene    = scene;
    this.type     = type;       // 'wolf' | 'zombie' | 'deer' | 'boar'
    this.state    = EState.IDLE;
    this.position = position.clone();
    this.velocity = new THREE.Vector3();
    this.rotation = 0;
    this.health   = this._maxHealth();
    this.attackCD = 0;
    this._stateTimer  = 0;
    this._patrolTarget = position.clone();
    this._aggroTimer  = 0;
    this._spawnPos    = position.clone();
    this._dead = false;
    this._healthBarEl = null;

    this.mesh  = this._buildMesh();
    this.mesh.userData.enemy = this;
    scene.add(this.mesh);

    this._buildHealthBar();
  }

  _maxHealth() {
    return { wolf: 60, zombie: 80, deer: 40, boar: 70 }[this.type] || 50;
  }

  _aggroRange() {
    return { wolf: CONFIG.WOLF_AGGRO, zombie: CONFIG.ZOMBIE_AGGRO, deer: 0, boar: 0 }[this.type] || 0;
  }

  _moveSpeed() {
    return { wolf: 6, zombie: 3, deer: 8, boar: 5 }[this.type] || 4;
  }

  _attackDamage() {
    return { wolf: 15, zombie: 12, deer: 5, boar: 20 }[this.type] || 10;
  }

  _buildMesh() {
    const grp = new THREE.Group();
    const colors = { wolf: 0x666666, zombie: 0x228b22, deer: 0xc8a97e, boar: 0x4a3728 };
    const mat    = new THREE.MeshLambertMaterial({ color: colors[this.type] || 0x888888 });

    if (this.type === 'wolf' || this.type === 'boar') {
      // Body + head (quadruped)
      const body = new THREE.Mesh(new THREE.BoxGeometry(1.2, 0.7, 0.6), mat);
      body.position.y = 0.35;
      const head = new THREE.Mesh(new THREE.BoxGeometry(0.5, 0.45, 0.5), mat);
      head.position.set(0.7, 0.65, 0);
      // Legs
      [-0.35, 0.35].forEach(x => [-0.4, 0.4].forEach(z => {
        const leg = new THREE.Mesh(new THREE.BoxGeometry(0.15, 0.5, 0.15), mat);
        leg.position.set(x, 0.1, z);
        grp.add(leg);
      }));
      grp.add(body, head);
    } else if (this.type === 'deer') {
      // Slender body + antlers
      const body = new THREE.Mesh(new THREE.BoxGeometry(1.0, 0.65, 0.5), mat);
      body.position.y = 0.7;
      const neck = new THREE.Mesh(new THREE.BoxGeometry(0.25, 0.6, 0.25), mat);
      neck.position.set(0.5, 1.0, 0);
      const head = new THREE.Mesh(new THREE.BoxGeometry(0.35, 0.35, 0.35), mat);
      head.position.set(0.6, 1.35, 0);
      // Legs
      [-0.2, 0.2].forEach(x => [-0.35, 0.35].forEach(z => {
        const leg = new THREE.Mesh(new THREE.BoxGeometry(0.1, 0.8, 0.1), mat);
        leg.position.set(x, 0.25, z);
        grp.add(leg);
      }));
      grp.add(body, neck, head);
    } else {
      // Zombie — bipedal humanoid
      const body = new THREE.Mesh(new THREE.BoxGeometry(0.5, 0.8, 0.3), mat);
      body.position.y = 0.8;
      const head = new THREE.Mesh(new THREE.BoxGeometry(0.4, 0.4, 0.4), mat);
      head.position.y = 1.4;
      const armL = new THREE.Mesh(new THREE.BoxGeometry(0.2, 0.7, 0.2), mat);
      armL.position.set(-0.4, 0.85, 0.1); armL.rotation.x = 0.4;
      const armR = armL.clone(); armR.position.x = 0.4;
      [-0.12, 0.12].forEach(x => {
        const leg = new THREE.Mesh(new THREE.BoxGeometry(0.2, 0.7, 0.2), mat);
        leg.position.set(x, 0.2, 0);
        grp.add(leg);
      });
      grp.add(body, head, armL, armR);
    }

    grp.castShadow = true;
    grp.position.copy(this.position);
    return grp;
  }

  _buildHealthBar() {
    const el  = document.createElement('div');
    el.className = 'enemy-hpbar';
    el.innerHTML = `<div class="enemy-hpbar-fill" style="width:100%"></div>`;
    document.body.appendChild(el);
    this._healthBarEl = el;
  }

  _updateHealthBar(camera, renderer) {
    if (!this._healthBarEl) return;
    if (this._dead) { this._healthBarEl.style.display = 'none'; return; }

    const pct    = Math.max(0, this.health / this._maxHealth() * 100);
    const fill   = this._healthBarEl.querySelector('.enemy-hpbar-fill');
    if (fill) fill.style.width = pct + '%';

    // Project to screen
    const pos3   = this.position.clone(); pos3.y += 2.5;
    const screen = pos3.project(camera);
    const w      = renderer.domElement.width;
    const h      = renderer.domElement.height;
    const sx     = (screen.x + 1) / 2 * w;
    const sy     = (1 - screen.y) / 2 * h;

    const dist   = camera.position.distanceTo(this.position);
    if (dist > 25 || screen.z > 1) {
      this._healthBarEl.style.display = 'none';
    } else {
      this._healthBarEl.style.display = 'block';
      this._healthBarEl.style.left    = (sx - 30) + 'px';
      this._healthBarEl.style.top     = (sy - 6)  + 'px';
    }
  }

  takeDamage(amount) {
    if (this._dead) return;
    this.health -= amount;
    if (this.type !== 'wolf' && this.type !== 'zombie') {
      // Passive animals flee when hit
      this.state = EState.FLEE;
      this._stateTimer = 8;
    } else {
      if (this.state !== EState.CHASE && this.state !== EState.ATTACK) {
        this.state = EState.CHASE;
      }
    }
    if (this.health <= 0) this._die();
  }

  _die() {
    this._dead = true;
    this.state  = EState.DEAD;
    this.mesh.visible = false;
    if (this._healthBarEl) this._healthBarEl.style.display = 'none';
  }

  isDead() { return this._dead; }

  getLoot() {
    const loot = {};
    switch (this.type) {
      case 'wolf':  Object.assign(loot, { raw_meat: 1 + Math.floor(Math.random() * 2) }); break;
      case 'zombie': if (Math.random() < 0.4) loot.stone = 1; if (Math.random() < 0.2) loot.iron = 1; break;
      case 'deer':  Object.assign(loot, { raw_meat: 2 + Math.floor(Math.random() * 2) }); break;
      case 'boar':  Object.assign(loot, { raw_meat: 2 + Math.floor(Math.random() * 3) }); break;
    }
    return loot;
  }

  update(dt, playerPos, isNight, terrain) {
    if (this._dead) return;
    this._stateTimer  -= dt;
    if (this.attackCD > 0) this.attackCD -= dt;

    const distToPlayer = this.position.distanceTo(playerPos);
    const aggroRange   = this._aggroRange();

    // ── State transitions ────────────────────────────────────────────────────
    switch (this.state) {
      case EState.IDLE:
        if (aggroRange > 0 && distToPlayer < aggroRange && (isNight || this.type === 'zombie')) {
          this.state = EState.CHASE;
        } else if (this._stateTimer <= 0) {
          this.state = EState.PATROL;
          this._stateTimer = 4 + Math.random() * 6;
          this._setRandomPatrol();
        }
        break;

      case EState.PATROL:
        if (aggroRange > 0 && distToPlayer < aggroRange && (isNight || this.type === 'zombie')) {
          this.state = EState.CHASE;
        } else if (this._stateTimer <= 0 || this.position.distanceTo(this._patrolTarget) < 1) {
          this.state = EState.IDLE;
          this._stateTimer = 2 + Math.random() * 3;
        }
        break;

      case EState.CHASE:
        if (distToPlayer < CONFIG.ENEMY_ATTACK_RANGE) {
          this.state = EState.ATTACK;
        } else if (distToPlayer > aggroRange * 1.8) {
          this.state = EState.PATROL; this._stateTimer = 4;
          this._setRandomPatrol();
        }
        break;

      case EState.ATTACK:
        if (distToPlayer > CONFIG.ENEMY_ATTACK_RANGE * 1.5) {
          this.state = EState.CHASE;
        }
        break;

      case EState.FLEE:
        if (this._stateTimer <= 0 || distToPlayer > 20) {
          this.state = EState.PATROL; this._stateTimer = 3;
        }
        break;
    }

    // ── State actions ────────────────────────────────────────────────────────
    let targetPos = null;
    switch (this.state) {
      case EState.PATROL: targetPos = this._patrolTarget; break;
      case EState.CHASE:  targetPos = playerPos; break;
      case EState.FLEE:
        // Move away from player
        const away = this.position.clone().sub(playerPos).normalize().multiplyScalar(15);
        targetPos  = this.position.clone().add(away);
        break;
    }

    if (targetPos) {
      const dir   = targetPos.clone().sub(this.position);
      dir.y = 0;
      const dist2 = dir.length();
      if (dist2 > 0.5) {
        dir.normalize();
        const speed = this._moveSpeed() * (this.state === EState.FLEE ? 1.4 : 1);
        this.position.addScaledVector(dir, speed * dt);
        this.rotation = Math.atan2(dir.x, dir.z);
      }
    }

    // Keep on terrain
    const gh = terrain.getGroundHeight(this.position.x, this.position.z);
    this.position.y = gh + 0.05;

    this.mesh.position.copy(this.position);
    this.mesh.rotation.y = this.rotation;

    // Animate slight bobbing
    this.mesh.position.y += Math.sin(Date.now() * 0.005 + this.rotation) * 0.03;

    // Attack player
    if (this.state === EState.ATTACK && this.attackCD <= 0) {
      this.attackCD = CONFIG.ENEMY_ATTACK_CD;
      return { type: 'attack', damage: this._attackDamage(), source: this.type };
    }
    return null;
  }

  _setRandomPatrol() {
    const range = 8;
    this._patrolTarget = new THREE.Vector3(
      this._spawnPos.x + (Math.random() - 0.5) * range * 2,
      0,
      this._spawnPos.z + (Math.random() - 0.5) * range * 2
    );
  }
}

// ── Enemy System ────────────────────────────────────────────────────────────────
class EnemySystem {
  constructor(game) {
    this.game    = game;
    this.enemies = [];
    this._spawnTimer = 30;
  }

  initialSpawn() {
    const pos = this.game.player.getPosition();
    for (let i = 0; i < 8; i++) {
      this._spawnRandom(pos, 40, 120);
    }
  }

  _spawnRandom(nearPos, minDist, maxDist) {
    if (this.enemies.length >= CONFIG.MAX_ENEMIES) return;
    const angle = Math.random() * Math.PI * 2;
    const dist  = minDist + Math.random() * (maxDist - minDist);
    const x     = nearPos.x + Math.cos(angle) * dist;
    const z     = nearPos.z + Math.sin(angle) * dist;
    const h     = this.game.terrain.getGroundHeight(x, z);
    if (h < 1) return;

    const types   = this.game.environment.isNight()
      ? ['wolf', 'wolf', 'zombie', 'zombie', 'deer', 'boar']
      : ['deer', 'deer', 'boar', 'wolf'];
    const type    = types[Math.floor(Math.random() * types.length)];
    const enemy   = new Enemy(this.game.scene, type, new THREE.Vector3(x, h, z));
    this.enemies.push(enemy);
  }

  update(dt) {
    const playerPos = this.game.player.getPosition();
    const isNight   = this.game.environment.isNight();

    // Update each enemy
    for (let i = this.enemies.length - 1; i >= 0; i--) {
      const e = this.enemies[i];

      if (e.isDead()) {
        // Wait 3s then remove
        if (!e._removeTimer) e._removeTimer = 3;
        e._removeTimer -= dt;
        e._updateHealthBar(this.game.camera, this.game.renderer);
        if (e._removeTimer <= 0) {
          this.game.scene.remove(e.mesh);
          if (e._healthBarEl) e._healthBarEl.remove();
          this.enemies.splice(i, 1);
        }
        continue;
      }

      const action = e.update(dt, playerPos, isNight, this.game.terrain);
      e._updateHealthBar(this.game.camera, this.game.renderer);

      if (action?.type === 'attack') {
        this.game.player.takeDamage(action.damage, action.source);
        this.game.audio.playEnemyGrowl();
      }

      // Despawn if too far (> 200 units)
      if (playerPos.distanceTo(e.position) > 200) {
        this.game.scene.remove(e.mesh);
        if (e._healthBarEl) e._healthBarEl.remove();
        this.enemies.splice(i, 1);
      }
    }

    // Periodic spawn
    this._spawnTimer -= dt;
    if (this._spawnTimer <= 0) {
      const interval = isNight ? 20 : 45;
      this._spawnTimer = interval + Math.random() * interval;
      const count = isNight ? CONFIG.NIGHT_SPAWN_MULTIPLIER : 1;
      for (let i = 0; i < count; i++) this._spawnRandom(playerPos, 40, 100);
    }
  }

  getEnemyMeshes() {
    return this.enemies.filter(e => !e.isDead()).flatMap(e => {
      const arr = [];
      e.mesh.traverse(c => { if (c.isMesh) arr.push(c); });
      return arr;
    });
  }

  killEnemy(enemy) {
    if (enemy.isDead()) return;
    enemy._die();
    const loot = enemy.getLoot();
    for (const [id, qty] of Object.entries(loot)) {
      this.game.inventory.addItem(id, qty);
      this.game.ui.notify(`+${qty} ${ITEMS[id]?.name || id}`, 'info');
    }
    this.game.player.addXP(CONFIG.XP_KILL);
    this.game.audio._play(220, 'sine', 0.3, 0.1);
  }
}
