'use strict';

class TerrainSystem {
  constructor(scene, noise) {
    this.scene = scene;
    this.noise = noise;
    this.chunks = new Map();
    this.resourceNodes = [];

    // Materials (vertex-colored terrain + object mats)
    this.mats = {
      terrain:   new THREE.MeshLambertMaterial({ vertexColors: true }),
      water:     new THREE.MeshLambertMaterial({ color: 0x1a5c99, transparent: true, opacity: 0.72, side: THREE.DoubleSide }),
      treeTrunk: new THREE.MeshLambertMaterial({ color: 0x4a2f0f }),
      treeLeaf1: new THREE.MeshLambertMaterial({ color: 0x1a6b1a }),
      treeLeaf2: new THREE.MeshLambertMaterial({ color: 0x228b22 }),
      rock:      new THREE.MeshLambertMaterial({ color: 0x666870 }),
      rockIron:  new THREE.MeshLambertMaterial({ color: 0x8b6d5c }),
      rockCoal:  new THREE.MeshLambertMaterial({ color: 0x333333 }),
    };

    this._createWater();
  }

  _createWater() {
    const geo  = new THREE.PlaneGeometry(2048, 2048);
    const mesh = new THREE.Mesh(geo, this.mats.water);
    mesh.rotation.x = -Math.PI / 2;
    mesh.position.y = CONFIG.SEA_LEVEL - 0.3;
    mesh.renderOrder = -1;
    this.scene.add(mesh);
  }

  // ── Height / biome ────────────────────────────────────────────────────────────
  getHeight(wx, wz) {
    const s = CONFIG.TERRAIN_SCALE;
    let h   = this.noise.fbm(wx * s, wz * s, 6, 0.5, 2.0);
    h = (h + 1) / 2;          // [0,1]
    h = Math.pow(h, 1.6);     // push toward plains with occasional peaks
    return h * CONFIG.HEIGHT_SCALE - 2;
  }

  getBiome(h, wx, wz) {
    if (h <= 0)  return 'water';
    if (h <  2)  return 'beach';
    if (h < 14) {
      const fn = this.noise.noise2D(wx * 0.025, wz * 0.025);
      return fn > 0.15 ? 'forest' : 'grassland';
    }
    if (h < 20)  return 'highland';
    return 'mountain';
  }

  _biomeColor(biome) {
    switch (biome) {
      case 'water':     return [0.1,  0.38, 0.6];
      case 'beach':     return [0.87, 0.78, 0.49];
      case 'grassland': return [0.2,  0.50, 0.18];
      case 'forest':    return [0.1,  0.35, 0.1];
      case 'highland':  return [0.42, 0.38, 0.28];
      case 'mountain':  return [0.55, 0.55, 0.56];
      default:          return [0.3,  0.5,  0.3];
    }
  }

  // ── Chunk management ──────────────────────────────────────────────────────────
  loadChunksAround(cx, cz, radius) {
    const keep = new Set();
    for (let dx = -radius; dx <= radius; dx++) {
      for (let dz = -radius; dz <= radius; dz++) {
        const key = `${cx+dx},${cz+dz}`;
        keep.add(key);
        if (!this.chunks.has(key)) this._buildChunk(cx + dx, cz + dz);
      }
    }
    for (const [key] of this.chunks) {
      if (!keep.has(key)) this._removeChunk(key);
    }
  }

  _buildChunk(cx, cz) {
    const key  = `${cx},${cz}`;
    const size = CONFIG.CHUNK_SIZE;
    const seg  = size - 1;

    const geo = new THREE.PlaneGeometry(size, size, seg, seg);
    geo.rotateX(-Math.PI / 2);
    const pos    = geo.attributes.position;
    const colors = [];

    for (let i = 0; i < pos.count; i++) {
      const wx = pos.getX(i) + cx * size;
      const wz = pos.getZ(i) + cz * size;
      const h  = this.getHeight(wx, wz);
      pos.setY(i, h);
      const [r, g, b] = this._biomeColor(this.getBiome(h, wx, wz));
      colors.push(r, g, b);
    }

    geo.setAttribute('color', new THREE.Float32BufferAttribute(colors, 3));
    geo.computeVertexNormals();

    const mesh = new THREE.Mesh(geo, this.mats.terrain);
    mesh.receiveShadow = true;
    this.scene.add(mesh);

    const nodes = this._spawnResourceNodes(cx, cz);
    this.chunks.set(key, { mesh, nodes });
  }

  _removeChunk(key) {
    const c = this.chunks.get(key);
    if (!c) return;
    this.scene.remove(c.mesh);
    c.mesh.geometry.dispose();
    c.nodes.forEach(n => {
      if (n.mesh) this.scene.remove(n.mesh);
      const idx = this.resourceNodes.indexOf(n);
      if (idx !== -1) this.resourceNodes.splice(idx, 1);
    });
    this.chunks.delete(key);
  }

  // ── Resource node spawning ────────────────────────────────────────────────────
  _seededRng(seed) {
    let s = (seed | 0) >>> 0 || 1;
    return () => { s = (Math.imul(s, 1664525) + 1013904223) >>> 0; return s / 0x100000000; };
  }

  _spawnResourceNodes(cx, cz) {
    const rng  = this._seededRng(cx * 73856093 ^ cz * 19349663);
    const size = CONFIG.CHUNK_SIZE;
    const nodes = [];

    for (let i = 0; i < 10; i++) {
      const wx = cx * size + rng() * size;
      const wz = cz * size + rng() * size;
      const h  = this.getHeight(wx, wz);
      if (h < 0.5) continue;

      const biome  = this.getBiome(h, wx, wz);
      const roll   = rng();
      let node;

      if ((biome === 'forest' || biome === 'grassland') && roll < 0.55) {
        node = this._makeTree(wx, h, wz, rng);
      } else if (roll < 0.8 && biome !== 'water' && biome !== 'beach') {
        node = this._makeRock(wx, h, wz, rng);
      } else if (biome === 'grassland' && roll > 0.9) {
        node = this._makeBush(wx, h, wz);
      }

      if (node) { nodes.push(node); this.resourceNodes.push(node); }
    }
    return nodes;
  }

  _makeTree(wx, h, wz, rng) {
    const grp = new THREE.Group();
    // Trunk
    const trunkH = 2 + rng() * 1.5;
    const trunk  = new THREE.Mesh(
      new THREE.CylinderGeometry(0.22, 0.32, trunkH, 6),
      this.mats.treeTrunk
    );
    trunk.position.y = trunkH / 2;
    trunk.castShadow  = true;
    grp.add(trunk);
    // Foliage – 3 stacked cones
    const leafMat = rng() > 0.5 ? this.mats.treeLeaf1 : this.mats.treeLeaf2;
    [[1.6, 2.6, trunkH * 0.5],
     [1.2, 2.2, trunkH * 0.7],
     [0.7, 1.6, trunkH + 0.5]].forEach(([r, h2, y]) => {
      const leaf = new THREE.Mesh(new THREE.ConeGeometry(r, h2, 7), leafMat);
      leaf.position.y = y; leaf.castShadow = true;
      grp.add(leaf);
    });

    grp.position.set(wx, h, wz);
    grp.userData.nodeType = 'tree';
    this.scene.add(grp);

    return {
      type: 'tree', mesh: grp,
      position: new THREE.Vector3(wx, h, wz),
      health: 100, maxHealth: 100,
      resources: { wood: 3 + Math.floor(rng() * 3) },
      depleted: false, respawnTimer: 0,
    };
  }

  _makeRock(wx, h, wz, rng) {
    const roll    = rng();
    let mat, resources;
    if      (roll < 0.55) { mat = this.mats.rock;     resources = { stone: 3 + Math.floor(rng() * 3) }; }
    else if (roll < 0.80) { mat = this.mats.rockCoal; resources = { stone: 1, coal: 2 + Math.floor(rng() * 2) }; }
    else                  { mat = this.mats.rockIron;  resources = { stone: 1, iron: 1 + Math.floor(rng() * 2) }; }

    const scale = 0.5 + rng() * 0.7;
    const mesh  = new THREE.Mesh(new THREE.DodecahedronGeometry(scale, 0), mat);
    mesh.position.set(wx, h + scale * 0.4, wz);
    mesh.rotation.set(rng() * 0.6, rng() * Math.PI * 2, rng() * 0.6);
    mesh.castShadow = true;
    mesh.userData.nodeType = 'rock';
    this.scene.add(mesh);

    return {
      type: 'rock', mesh,
      position: new THREE.Vector3(wx, h, wz),
      health: 100, maxHealth: 100,
      resources, depleted: false, respawnTimer: 0,
    };
  }

  _makeBush(wx, h, wz) {
    const mesh = new THREE.Mesh(
      new THREE.SphereGeometry(0.5, 6, 5),
      new THREE.MeshLambertMaterial({ color: 0x1a7a35 })
    );
    mesh.position.set(wx, h + 0.4, wz);
    mesh.userData.nodeType = 'bush';
    this.scene.add(mesh);
    return {
      type: 'bush', mesh,
      position: new THREE.Vector3(wx, h, wz),
      health: 20, maxHealth: 20,
      resources: { berries: 2 },
      depleted: false, respawnTimer: 0,
    };
  }

  // ── API ────────────────────────────────────────────────────────────────────────
  getGroundHeight(wx, wz) { return this.getHeight(wx, wz); }

  getNearestNode(pos, maxDist = 3.5) {
    let best = null, bestDist = Infinity;
    for (const n of this.resourceNodes) {
      if (n.depleted) continue;
      const dx = n.position.x - pos.x;
      const dz = n.position.z - pos.z;
      const d  = Math.sqrt(dx * dx + dz * dz);
      if (d < maxDist && d < bestDist) { bestDist = d; best = n; }
    }
    return best;
  }

  harvestNode(node, damage) {
    node.health -= damage;
    if (node.health <= 0) {
      node.depleted     = true;
      node.health       = 0;
      node.respawnTimer = node.type === 'tree' ? CONFIG.TREE_RESPAWN : CONFIG.ROCK_RESPAWN;
      if (node.mesh) node.mesh.visible = false;
      return { ...node.resources };
    }
    return null;
  }

  update(dt) {
    for (const n of this.resourceNodes) {
      if (!n.depleted) continue;
      n.respawnTimer -= dt;
      if (n.respawnTimer <= 0) {
        n.depleted = false;
        n.health   = n.maxHealth;
        if (n.mesh) n.mesh.visible = true;
      }
    }
  }

  getRaycastObjects() {
    const objs = [];
    for (const [, c] of this.chunks) objs.push(c.mesh);
    return objs;
  }
}
