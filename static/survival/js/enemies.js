'use strict';

// ── Enemy States ────────────────────────────────────────────────────────────────
const EState = { IDLE: 0, PATROL: 1, CHASE: 2, ATTACK: 3, FLEE: 4, DEAD: 5 };

class Enemy {
  constructor(scene, type, position) {
    this.scene    = scene;
    this.type     = type;       // 'wolf'|'zombie'|'deer'|'boar'|'capybara'
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
    return { wolf: 60, zombie: 80, deer: 40, boar: 70, capybara: 50 }[this.type] || 50;
  }

  _aggroRange() {
    return { wolf: CONFIG.WOLF_AGGRO, zombie: CONFIG.ZOMBIE_AGGRO, deer: 0, boar: 0, capybara: 0 }[this.type] || 0;
  }

  _moveSpeed() {
    return { wolf: 6, zombie: 3, deer: 8, boar: 5, capybara: 3.5 }[this.type] || 4;
  }

  _attackDamage() {
    return { wolf: 15, zombie: 12, deer: 5, boar: 20, capybara: 0 }[this.type] || 10;
  }

  _buildMesh() {
    const grp = new THREE.Group();

    if (this.type === 'wolf') {
      this._buildWolf(grp);
    } else if (this.type === 'boar') {
      this._buildBoar(grp);
    } else if (this.type === 'deer') {
      this._buildDeer(grp);
    } else if (this.type === 'zombie') {
      this._buildZombie(grp);
    } else if (this.type === 'capybara') {
      this._buildCapybara(grp);
    }

    grp.castShadow = true;
    grp.position.copy(this.position);
    return grp;
  }

  _buildWolf(g) {
    const fur  = new THREE.MeshLambertMaterial({ color: 0x808080 });
    const dark = new THREE.MeshLambertMaterial({ color: 0x4a4a4a });
    // Body
    const body = new THREE.Mesh(new THREE.BoxGeometry(1.3, 0.65, 0.58), fur);
    body.position.y = 0.55;
    // Neck
    const neck = new THREE.Mesh(new THREE.CylinderGeometry(0.18, 0.22, 0.42, 6), fur);
    neck.position.set(0.62, 0.78, 0); neck.rotation.z = 0.6;
    // Head
    const head = new THREE.Mesh(new THREE.BoxGeometry(0.52, 0.44, 0.44), fur);
    head.position.set(0.95, 0.9, 0);
    // Snout
    const snout = new THREE.Mesh(new THREE.BoxGeometry(0.32, 0.22, 0.3), dark);
    snout.position.set(1.22, 0.82, 0);
    // Eyes
    [-0.14, 0.14].forEach(z => {
      const eye = new THREE.Mesh(new THREE.SphereGeometry(0.07, 5, 5),
        new THREE.MeshLambertMaterial({ color: 0xffaa00 }));
      eye.position.set(1.15, 0.96, z);
      g.add(eye);
    });
    // Ears
    [-0.18, 0.18].forEach(z => {
      const ear = new THREE.Mesh(new THREE.ConeGeometry(0.1, 0.25, 5), dark);
      ear.position.set(0.88, 1.12, z);
      g.add(ear);
    });
    // Tail
    const tail = new THREE.Mesh(new THREE.CylinderGeometry(0.06, 0.03, 0.7, 5), fur);
    tail.position.set(-0.72, 0.68, 0); tail.rotation.z = -0.7;
    // Legs
    this._legs = [];
    [[-0.38, 0, -0.22], [-0.38, 0, 0.22], [0.38, 0, -0.22], [0.38, 0, 0.22]].forEach(([x,y,z]) => {
      const leg = new THREE.Mesh(new THREE.CylinderGeometry(0.09, 0.07, 0.55, 5), dark);
      leg.position.set(x, 0.27, z);
      g.add(leg); this._legs.push(leg);
    });
    g.add(body, neck, head, snout, tail);
  }

  _buildBoar(g) {
    const fur  = new THREE.MeshLambertMaterial({ color: 0x5a3a28 });
    const dark = new THREE.MeshLambertMaterial({ color: 0x3a2018 });
    const body = new THREE.Mesh(new THREE.SphereGeometry(0.65, 8, 6), fur);
    body.scale.set(1.35, 0.85, 0.9); body.position.y = 0.58;
    const head = new THREE.Mesh(new THREE.SphereGeometry(0.38, 7, 6), fur);
    head.scale.set(1.2, 0.95, 1.0); head.position.set(0.78, 0.7, 0);
    const snout = new THREE.Mesh(new THREE.CylinderGeometry(0.14, 0.16, 0.3, 6), dark);
    snout.rotation.z = Math.PI / 2; snout.position.set(1.1, 0.64, 0);
    // Tusks
    [-0.1, 0.1].forEach(z => {
      const tusk = new THREE.Mesh(new THREE.CylinderGeometry(0.04, 0.02, 0.35, 5),
        new THREE.MeshLambertMaterial({ color: 0xf0e0a0 }));
      tusk.rotation.z = -Math.PI / 2.5; tusk.position.set(1.15, 0.5, z);
      g.add(tusk);
    });
    this._legs = [];
    [[-0.3,0,-0.26],[0.3,0,-0.26],[-0.3,0,0.26],[0.3,0,0.26]].forEach(([x,y,z]) => {
      const leg = new THREE.Mesh(new THREE.CylinderGeometry(0.1, 0.08, 0.5, 5), dark);
      leg.position.set(x, 0.25, z); g.add(leg); this._legs.push(leg);
    });
    g.add(body, head, snout);
  }

  _buildDeer(g) {
    const fur  = new THREE.MeshLambertMaterial({ color: 0xc8a060 });
    const dark = new THREE.MeshLambertMaterial({ color: 0x8a5a30 });
    const body = new THREE.Mesh(new THREE.SphereGeometry(0.6, 7, 6), fur);
    body.scale.set(1.4, 0.8, 0.75); body.position.y = 0.85;
    const neck = new THREE.Mesh(new THREE.CylinderGeometry(0.14, 0.18, 0.65, 6), fur);
    neck.position.set(0.68, 1.05, 0); neck.rotation.z = 0.55;
    const head = new THREE.Mesh(new THREE.SphereGeometry(0.27, 7, 6), fur);
    head.position.set(0.98, 1.32, 0);
    const snout = new THREE.Mesh(new THREE.BoxGeometry(0.22, 0.18, 0.2), dark);
    snout.position.set(1.2, 1.25, 0);
    // Antlers
    [-0.1, 0.1].forEach(z => {
      const branch = (ox, oy, oz, rz) => {
        const m = new THREE.Mesh(new THREE.CylinderGeometry(0.025, 0.04, 0.45, 5),
          new THREE.MeshLambertMaterial({ color: 0x6b4020 }));
        m.position.set(ox, oy, oz); m.rotation.z = rz; g.add(m);
      };
      branch(0.92, 1.62, z, 0.2 * (z > 0 ? 1 : -1));
      branch(0.86, 1.9, z + z * 0.5, 0.5 * (z > 0 ? 1 : -1));
    });
    // White belly patch
    const belly = new THREE.Mesh(new THREE.SphereGeometry(0.35, 6, 5),
      new THREE.MeshLambertMaterial({ color: 0xf0e0c0 }));
    belly.scale.set(1.1, 0.6, 0.7); belly.position.set(0, 0.7, 0);
    // Eyes
    [-0.13, 0.13].forEach(z => {
      const eye = new THREE.Mesh(new THREE.SphereGeometry(0.07, 5, 5),
        new THREE.MeshLambertMaterial({ color: 0x2a1a0a }));
      eye.position.set(1.08, 1.36, z); g.add(eye);
    });
    this._legs = [];
    [[-0.3,0,-0.22],[0.3,0,-0.22],[-0.3,0,0.22],[0.3,0,0.22]].forEach(([x,y,z]) => {
      const leg = new THREE.Mesh(new THREE.CylinderGeometry(0.07, 0.05, 0.9, 5), dark);
      leg.position.set(x, 0.3, z); g.add(leg); this._legs.push(leg);
    });
    g.add(body, neck, head, snout, belly);
  }

  _buildZombie(g) {
    const skin  = new THREE.MeshLambertMaterial({ color: 0x4a7a3a });
    const cloth = new THREE.MeshLambertMaterial({ color: 0x5a5040 });
    const dark  = new THREE.MeshLambertMaterial({ color: 0x2a3020 });
    // Torso
    const torso = new THREE.Mesh(new THREE.BoxGeometry(0.55, 0.82, 0.32), cloth);
    torso.position.y = 0.88;
    // Hips
    const hips = new THREE.Mesh(new THREE.BoxGeometry(0.52, 0.3, 0.3), cloth);
    hips.position.y = 0.42;
    // Head
    const head = new THREE.Mesh(new THREE.BoxGeometry(0.42, 0.44, 0.4), skin);
    head.position.y = 1.43;
    // Hair clumps
    for (let i = 0; i < 5; i++) {
      const hair = new THREE.Mesh(new THREE.BoxGeometry(0.1, 0.12, 0.1),
        new THREE.MeshLambertMaterial({ color: 0x1a1a0a }));
      hair.position.set((Math.random() - 0.5) * 0.3, 1.64, (Math.random() - 0.5) * 0.2);
      g.add(hair);
    }
    // Eyes (glowing red)
    [-0.1, 0.1].forEach(z => {
      const eye = new THREE.Mesh(new THREE.SphereGeometry(0.07, 5, 5),
        new THREE.MeshLambertMaterial({ color: 0xff3300, emissive: 0xff1100, emissiveIntensity: 0.8 }));
      eye.position.set(0.18, 1.47, z); g.add(eye);
    });
    // Arms (outstretched zombie-style)
    const armL = new THREE.Mesh(new THREE.CylinderGeometry(0.09, 0.08, 0.72, 6), skin);
    armL.position.set(-0.42, 1.0, 0.1); armL.rotation.set(0.4, 0, 0.5);
    const armR = new THREE.Mesh(new THREE.CylinderGeometry(0.09, 0.08, 0.72, 6), skin);
    armR.position.set( 0.42, 1.0, 0.1); armR.rotation.set(0.4, 0, -0.5);
    this._legs = [];
    [-0.14, 0.14].forEach(x => {
      const leg = new THREE.Mesh(new THREE.CylinderGeometry(0.1, 0.09, 0.75, 6), dark);
      leg.position.set(x, 0.04, 0); g.add(leg); this._legs.push(leg);
    });
    g.add(torso, hips, head, armL, armR);
  }

  _buildCapybara(g) {
    // Detailed, cute capybara model
    const fur   = new THREE.MeshLambertMaterial({ color: 0x9a7420 });
    const dark  = new THREE.MeshLambertMaterial({ color: 0x6b4a0e });
    const light = new THREE.MeshLambertMaterial({ color: 0xc0a050 });
    const nose  = new THREE.MeshLambertMaterial({ color: 0x3d2208 });

    // Body — large rounded rectangle, capybaras are barrel-shaped
    const body = new THREE.Mesh(new THREE.SphereGeometry(0.82, 8, 7), fur);
    body.scale.set(1.55, 0.85, 0.92); body.position.y = 0.72;

    // Shoulder hump
    const hump = new THREE.Mesh(new THREE.SphereGeometry(0.55, 7, 6), fur);
    hump.scale.set(0.85, 0.75, 0.75); hump.position.set(0.35, 1.05, 0);

    // Head — wide, flat-nosed
    const head = new THREE.Mesh(new THREE.SphereGeometry(0.55, 8, 7), fur);
    head.scale.set(1.1, 0.88, 0.92); head.position.set(1.25, 0.92, 0);
    this._capyHead = head;

    // Snout — wide rectangular nose
    const snout = new THREE.Mesh(new THREE.BoxGeometry(0.44, 0.28, 0.38), dark);
    snout.position.set(1.72, 0.84, 0);

    // Nostrils
    [-0.11, 0.11].forEach(z => {
      const nostril = new THREE.Mesh(new THREE.SphereGeometry(0.065, 5, 4), nose);
      nostril.position.set(1.93, 0.86, z); g.add(nostril);
    });

    // Lips/mouth line
    const mouth = new THREE.Mesh(new THREE.BoxGeometry(0.3, 0.04, 0.02), dark);
    mouth.position.set(1.82, 0.72, 0); g.add(mouth);

    // Eyes — small, dark, expressive
    [-0.22, 0.22].forEach(z => {
      const eyeW = new THREE.Mesh(new THREE.SphereGeometry(0.1, 6, 6),
        new THREE.MeshLambertMaterial({ color: 0xffffff }));
      eyeW.position.set(1.55, 1.06, z);
      const eyeP = new THREE.Mesh(new THREE.SphereGeometry(0.072, 5, 5),
        new THREE.MeshLambertMaterial({ color: 0x1a1008 }));
      eyeP.position.set(1.58, 1.06, z);
      const shine = new THREE.Mesh(new THREE.SphereGeometry(0.03, 4, 4),
        new THREE.MeshLambertMaterial({ color: 0xffffff }));
      shine.position.set(1.61, 1.09, z + 0.04);
      g.add(eyeW, eyeP, shine);
    });

    // Ears — rounded, close to head
    [-0.24, 0.24].forEach(z => {
      const ear = new THREE.Mesh(new THREE.CylinderGeometry(0.14, 0.16, 0.1, 7), dark);
      ear.position.set(1.18, 1.38, z); g.add(ear);
      const earInner = new THREE.Mesh(new THREE.CylinderGeometry(0.08, 0.1, 0.06, 7),
        new THREE.MeshLambertMaterial({ color: 0xc47040 }));
      earInner.position.set(1.18, 1.4, z); g.add(earInner);
    });

    // Light belly patch
    const belly = new THREE.Mesh(new THREE.SphereGeometry(0.65, 7, 6), light);
    belly.scale.set(1.1, 0.55, 0.72); belly.position.set(0, 0.38, 0);

    // Tiny tail
    const tail = new THREE.Mesh(new THREE.SphereGeometry(0.12, 5, 4), dark);
    tail.position.set(-1.28, 0.78, 0);

    // 4 short stubby legs
    this._legs = [];
    [[-0.65, 0, -0.38], [0.55, 0, -0.38], [-0.65, 0, 0.38], [0.55, 0, 0.38]].forEach(([x,y,z]) => {
      const upper = new THREE.Mesh(new THREE.CylinderGeometry(0.14, 0.12, 0.38, 6), dark);
      upper.position.set(x, 0.35, z);
      const lower = new THREE.Mesh(new THREE.CylinderGeometry(0.1, 0.12, 0.32, 6), fur);
      lower.position.set(x, 0.1, z);
      const foot  = new THREE.Mesh(new THREE.BoxGeometry(0.28, 0.1, 0.22), dark);
      foot.position.set(x + 0.06, 0.02, z);
      g.add(upper, lower, foot);
      this._legs.push(upper); // animate upper leg
    });

    g.add(body, hump, head, snout, belly, tail);
    g.scale.setScalar(0.85);
  }

  _buildHealthBar() {
    const el  = document.createElement('div');
    el.className = 'enemy-hpbar';
    el.style.display = 'none';
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
      case 'wolf':     Object.assign(loot, { raw_meat: 1 + Math.floor(Math.random() * 2) }); break;
      case 'zombie':   if (Math.random() < 0.4) loot.stone = 1; if (Math.random() < 0.2) loot.iron = 1; break;
      case 'deer':     Object.assign(loot, { raw_meat: 2 + Math.floor(Math.random() * 2) }); break;
      case 'boar':     Object.assign(loot, { raw_meat: 2 + Math.floor(Math.random() * 3) }); break;
      case 'capybara': Object.assign(loot, { raw_meat: 1, berries: 1 }); break;
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

    // Animate legs
    if (this._legs && this._legs.length > 0) {
      const t = Date.now() * 0.004;
      const moving = this.state === EState.PATROL || this.state === EState.CHASE || this.state === EState.FLEE;
      const amp = moving ? 0.38 : 0.05;
      this._legs.forEach((leg, i) => {
        leg.rotation.x = Math.sin(t + i * Math.PI / 2) * amp;
      });
    }
    // Capybara head bob / ear twitch
    if (this.type === 'capybara' && this._capyHead) {
      const t = Date.now() * 0.0015;
      this._capyHead.rotation.y = Math.sin(t * 0.7) * 0.18;
      this._capyHead.position.y = 0.92 + Math.sin(t * 2) * 0.015;
    }

    // Subtle body bob while moving
    if (this.state === EState.PATROL || this.state === EState.CHASE) {
      this.mesh.position.y += Math.sin(Date.now() * 0.012) * 0.04;
    }

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
      ? ['wolf', 'wolf', 'zombie', 'zombie', 'deer', 'boar', 'capybara']
      : ['deer', 'deer', 'boar', 'capybara', 'capybara', 'wolf'];
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
