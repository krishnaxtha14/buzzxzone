'use strict';

class BuildingSystem {
  constructor(game) {
    this.game       = game;
    this._open      = false;
    this._placing   = null;   // type string currently being placed
    this._ghost     = null;   // THREE.Object3D ghost preview
    this._structures = [];    // placed structures

    // Ghost materials
    this._matOk  = new THREE.MeshLambertMaterial({ color: 0x44ff44, transparent: true, opacity: 0.5 });
    this._matBad = new THREE.MeshLambertMaterial({ color: 0xff4444, transparent: true, opacity: 0.5 });

    this._raycaster = new THREE.Raycaster();
    this._center    = new THREE.Vector2(0, 0);

    document.getElementById('btn-close-build').addEventListener('click', () => this.close());
    document.querySelectorAll('.build-item').forEach(el => {
      el.addEventListener('click', () => {
        const t = el.dataset.type;
        if (t === 'cancel') this.cancelPlacement();
        else { this.startPlacement(t); this.close(); }
      });
    });

    document.addEventListener('click', e => {
      if (this._placing && e.button === 0 && window.GAME?.state === 'playing') {
        if (this._ghost) this._placeCurrent();
      }
    });

    document.addEventListener('keydown', e => {
      if (e.code === 'KeyR' && this._placing) {
        if (this._ghost) this._ghost.rotation.y += Math.PI / 2;
      }
      if (e.code === 'Escape' && this._placing) this.cancelPlacement();
    });
  }

  open() {
    this._open = true;
    document.getElementById('building-panel').classList.remove('hidden');
  }

  close() {
    this._open = false;
    document.getElementById('building-panel').classList.add('hidden');
    if (this.game.state === 'playing') this.game.player.controls.lock();
  }

  isOpen() { return this._open; }

  startPlacement(type) {
    if (this._ghost) this.game.scene.remove(this._ghost);
    this._placing = type;
    this._ghost   = this._buildGhost(type);
    if (this._ghost) this.game.scene.add(this._ghost);
    this.game.ui.notify('Right-click or [Esc] to cancel · [R] to rotate', 'info');
  }

  startPlacementFromItem(id) {
    this.startPlacement(id);
    if (!this.game.player.controls.isLocked) this.game.player.controls.lock();
  }

  cancelPlacement() {
    if (this._ghost) { this.game.scene.remove(this._ghost); this._ghost = null; }
    this._placing = null;
    document.querySelectorAll('.build-item').forEach(e => e.classList.remove('active'));
  }

  _buildGhost(type) {
    const geo = this._getGeometry(type);
    if (!geo) return null;
    const mesh = new THREE.Mesh(geo, this._matOk.clone());
    mesh.transparent = true;
    return mesh;
  }

  _getGeometry(type) {
    switch (type) {
      case 'wooden_floor':   return new THREE.BoxGeometry(CONFIG.BUILD_GRID, 0.2, CONFIG.BUILD_GRID);
      case 'wooden_wall':    return new THREE.BoxGeometry(CONFIG.BUILD_GRID, 3, 0.2);
      case 'wooden_door':    return new THREE.BoxGeometry(1, 3, 0.2);
      case 'campfire':       return new THREE.CylinderGeometry(0.6, 0.8, 0.6, 8);
      case 'workbench':      return new THREE.BoxGeometry(1.5, 0.9, 0.9);
      case 'storage_chest':  return new THREE.BoxGeometry(1.2, 0.8, 0.8);
      case 'torch':          return new THREE.CylinderGeometry(0.06, 0.06, 0.8, 6);
      default:               return new THREE.BoxGeometry(1, 1, 1);
    }
  }

  _getSnapHeight(type) {
    switch (type) {
      case 'wooden_floor': return 0.1;
      case 'wooden_wall':
      case 'wooden_door':  return 1.5;
      case 'campfire':     return 0.3;
      default:             return 0.45;
    }
  }

  _snapToGrid(v) {
    const g = CONFIG.BUILD_GRID;
    return new THREE.Vector3(
      Math.round(v.x / g) * g,
      v.y,
      Math.round(v.z / g) * g
    );
  }

  _placeCurrent() {
    if (!this._placing || !this._ghost) return;

    // Check player has cost
    const cost = BUILD_COSTS[this._placing];
    if (cost) {
      for (const [id, qty] of Object.entries(cost)) {
        if (this.game.inventory.countItem(id) < qty) {
          this.game.ui.notify(`Need ${qty} ${ITEMS[id]?.name || id}!`, 'error');
          return;
        }
      }
      for (const [id, qty] of Object.entries(cost)) {
        this.game.inventory.removeItem(id, qty);
      }
    } else {
      // Consumed from inventory as item
      if (!this.game.inventory.removeItem(this._placing, 1)) {
        this.game.ui.notify('Not enough materials!', 'error');
        return;
      }
    }

    const pos  = this._ghost.position.clone();
    const rotY = this._ghost.rotation.y;
    const type = this._placing;

    // Create permanent structure mesh
    const geo  = this._getGeometry(type);
    const mat  = this._getStructureMat(type);
    const mesh = new THREE.Mesh(geo, mat);
    mesh.position.copy(pos);
    mesh.rotation.y = rotY;
    mesh.castShadow = mesh.receiveShadow = true;
    mesh.userData.structureType = type;
    this.game.scene.add(mesh);

    // Add lights for campfire/torch
    if (type === 'campfire') {
      const light = new THREE.PointLight(0xff6600, 2, 12);
      light.position.copy(pos); light.position.y += 1.5;
      this.game.scene.add(light);
      this._structures.push({ type, mesh, light, position: pos.clone(), rotation: rotY });
    } else if (type === 'torch') {
      const light = new THREE.PointLight(0xffaa44, 1.5, 8);
      light.position.copy(pos); light.position.y += 1;
      this.game.scene.add(light);
      this._structures.push({ type, mesh, light, position: pos.clone(), rotation: rotY });
    } else {
      this._structures.push({ type, mesh, position: pos.clone(), rotation: rotY });
    }

    this.game.audio.playBuild();
    this.game.player.addXP(CONFIG.XP_BUILD);
    this.game.ui.notify(`${ITEMS[type]?.name || type} placed!`, 'success');
  }

  _getStructureMat(type) {
    switch (type) {
      case 'campfire':      return new THREE.MeshLambertMaterial({ color: 0x333333 });
      case 'workbench':     return new THREE.MeshLambertMaterial({ color: 0x8b5e3c });
      case 'storage_chest': return new THREE.MeshLambertMaterial({ color: 0x7a5230 });
      case 'torch':         return new THREE.MeshLambertMaterial({ color: 0x4a2f0f });
      default:              return new THREE.MeshLambertMaterial({ color: 0x6b4226 });
    }
  }

  hasPlaced(type) {
    return this._structures.some(s => s.type === type);
  }

  update(dt) {
    if (!this._placing || !this._ghost || !this.game.player.controls.isLocked) return;

    // Raycast from camera center to find placement position
    this._raycaster.setFromCamera(this._center, this.game.camera);
    const targets = this.game.terrain.getRaycastObjects();
    const hits    = this._raycaster.intersectObjects(targets, false);

    if (hits.length > 0) {
      let pos = hits[0].point.clone();
      pos = this._snapToGrid(pos);
      pos.y = this.game.terrain.getGroundHeight(pos.x, pos.z) + this._getSnapHeight(this._placing);

      this._ghost.position.copy(pos);
      // Validate: check not too far
      const playerPos = this.game.player.getPosition();
      const dx = pos.x - playerPos.x, dz = pos.z - playerPos.z;
      const dist = Math.sqrt(dx*dx + dz*dz);
      const valid = dist < 10;

      this._ghost.material.color.setHex(valid ? 0x44ff44 : 0xff4444);
      this._ghost.material.opacity = valid ? 0.55 : 0.35;
    }
  }

  getStructures() { return this._structures; }

  loadStructures(data) {
    if (!data) return;
    data.forEach(s => {
      const geo  = this._getGeometry(s.type);
      const mat  = this._getStructureMat(s.type);
      const mesh = new THREE.Mesh(geo, mat);
      mesh.position.set(s.position.x, s.position.y, s.position.z);
      mesh.rotation.y = s.rotation || 0;
      mesh.castShadow = mesh.receiveShadow = true;
      this.game.scene.add(mesh);
      this._structures.push({ ...s, mesh });
    });
  }
}
