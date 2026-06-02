'use strict';

class TerrainSystem {
  constructor(scene, noise) {
    this.scene = scene;
    this.noise = noise;
    this.chunks = new Map();
    this.resourceNodes = [];

    this.mats = {
      terrain:   new THREE.MeshLambertMaterial({ vertexColors: true }),
      water:     new THREE.MeshLambertMaterial({ color: 0x1a5c99, transparent: true, opacity: 0.72, side: THREE.DoubleSide }),
      rock:      new THREE.MeshLambertMaterial({ color: 0x7a7870 }),
      rockCoal:  new THREE.MeshLambertMaterial({ color: 0x2a2a2a }),
      rockIron:  new THREE.MeshLambertMaterial({ color: 0x9e7060 }),
      rockSnow:  new THREE.MeshLambertMaterial({ color: 0xe0e8f0 }),
    };

    this._createWater();
  }

  _createWater() {
    const geo  = new THREE.PlaneGeometry(2048, 2048, 4, 4);
    const mesh = new THREE.Mesh(geo, this.mats.water);
    mesh.rotation.x = -Math.PI / 2;
    mesh.position.y = CONFIG.SEA_LEVEL - 0.25;
    mesh.renderOrder = -1;
    this.scene.add(mesh);
    // Animate water Y gently in update
    this._waterMesh = mesh;
    this._waterTime = 0;
  }

  // ── Height & biome ────────────────────────────────────────────────────────
  getHeight(wx, wz) {
    const s = CONFIG.TERRAIN_SCALE;
    let h   = this.noise.fbm(wx * s, wz * s, 7, 0.52, 2.1);
    h = (h + 1) / 2;
    h = Math.pow(h, 1.55);
    return h * CONFIG.HEIGHT_SCALE - 2;
  }

  getBiome(h, wx, wz) {
    if (h <= 0)  return 'water';
    if (h <  2)  return 'beach';
    if (h < 14) {
      const fn = this.noise.noise2D(wx * 0.022, wz * 0.022);
      return fn > 0.12 ? 'forest' : 'grassland';
    }
    if (h < 20) return 'highland';
    return 'mountain';
  }

  _biomeColor(biome, variation) {
    const v = (variation || 0) * 0.05;
    switch (biome) {
      case 'water':     return [0.08 + v, 0.35 + v, 0.58];
      case 'beach':     return [0.84 + v, 0.76 + v, 0.48 + v];
      case 'grassland': return [0.15 + v, 0.48 + v, 0.14];
      case 'forest':    return [0.08 + v, 0.32 + v, 0.08];
      case 'highland':  return [0.40 + v, 0.37 + v, 0.27 + v];
      case 'mountain':  return [0.52 + v, 0.52 + v, 0.54 + v];
      default:          return [0.2,  0.45, 0.2];
    }
  }

  // ── Chunk management ──────────────────────────────────────────────────────
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
    const key     = `${cx},${cz}`;
    const size    = CONFIG.CHUNK_SIZE;
    const seg     = 31;   // 32×32 grid — smooth detailed terrain
    const offsetX = cx * size;
    const offsetZ = cz * size;

    const geo = new THREE.PlaneGeometry(size, size, seg, seg);
    geo.rotateX(-Math.PI / 2);
    const pos    = geo.attributes.position;
    const colors = [];

    for (let i = 0; i < pos.count; i++) {
      const wx = pos.getX(i) + offsetX;
      const wz = pos.getZ(i) + offsetZ;
      const h  = this.getHeight(wx, wz);
      pos.setY(i, h);
      // Subtle per-vertex variation for organic look
      const vari = this.noise.noise2D(wx * 0.4, wz * 0.4) * 0.5;
      const [r, g, b] = this._biomeColor(this.getBiome(h, wx, wz), vari);
      colors.push(r, g, b);
    }

    pos.needsUpdate = true;
    geo.setAttribute('color', new THREE.Float32BufferAttribute(colors, 3));
    geo.computeVertexNormals();

    const mesh = new THREE.Mesh(geo, this.mats.terrain);
    mesh.position.set(offsetX, 0, offsetZ);
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
      if (n.mesh) { this.scene.remove(n.mesh); }
      const idx = this.resourceNodes.indexOf(n);
      if (idx !== -1) this.resourceNodes.splice(idx, 1);
    });
    this.chunks.delete(key);
  }

  // ── Seeded RNG helper ─────────────────────────────────────────────────────
  _seededRng(seed) {
    let s = (seed | 0) >>> 0 || 1;
    return () => { s = (Math.imul(s, 1664525) + 1013904223) >>> 0; return s / 0x100000000; };
  }

  // ── Resource node spawning ────────────────────────────────────────────────
  _spawnResourceNodes(cx, cz) {
    const rng  = this._seededRng(cx * 73856093 ^ cz * 19349663);
    const size = CONFIG.CHUNK_SIZE;
    const nodes = [];

    for (let i = 0; i < 10; i++) {
      const wx = cx * size + rng() * size;
      const wz = cz * size + rng() * size;
      const h  = this.getHeight(wx, wz);
      if (h < 0.5) continue;
      const biome = this.getBiome(h, wx, wz);
      const roll  = rng();
      let   node;

      if ((biome === 'forest' || biome === 'grassland') && roll < 0.55) {
        node = this._makeTree(wx, h, wz, rng);
      } else if (roll < 0.82 && biome !== 'water' && biome !== 'beach') {
        node = this._makeRock(wx, h, wz, rng, biome);
      } else if (biome === 'grassland' && roll > 0.88) {
        node = this._makeBush(wx, h, wz, rng);
      }
      if (node) { nodes.push(node); this.resourceNodes.push(node); }
    }
    return nodes;
  }

  // ── Detailed Tree ─────────────────────────────────────────────────────────
  _makeTree(wx, h, wz, rng) {
    const grp    = new THREE.Group();
    const trunkH = 3.0 + rng() * 2.5;
    const thick  = 0.18 + rng() * 0.1;

    // Bark — warm brown, per-tree variation
    const barkL  = 0.17 + rng() * 0.10;
    const barkMat = new THREE.MeshLambertMaterial({
      color: new THREE.Color().setHSL(0.07 + rng() * 0.03, 0.55, barkL),
    });

    // Trunk (4 tapered cylinder sections for realistic shape)
    for (let s = 0; s < 4; s++) {
      const t    = s / 3;
      const botR = thick * (1.3 - t * 0.6);
      const topR = thick * (1.2 - t * 0.7);
      const sH   = trunkH / 4;
      const seg  = new THREE.Mesh(
        new THREE.CylinderGeometry(topR, botR, sH, 9),
        barkMat
      );
      seg.position.y = s * sH + sH / 2;
      seg.rotation.y = rng() * 0.4;
      seg.castShadow = true;
      grp.add(seg);
    }

    // Root flare — wide base for realistic look
    const rootFlare = new THREE.Mesh(
      new THREE.CylinderGeometry(thick * 1.3, thick * 2.8, 0.45, 9),
      barkMat
    );
    rootFlare.position.y = 0.22;
    grp.add(rootFlare);

    // Foliage — 5-7 cone layers with 2-tone greens
    const numLayers = 5 + Math.floor(rng() * 3);
    const leafHue   = 0.27 + rng() * 0.08;
    const leafSatA  = 0.65 + rng() * 0.25;
    const matA = new THREE.MeshLambertMaterial({ color: new THREE.Color().setHSL(leafHue, leafSatA, 0.19 + rng() * 0.07) });
    const matB = new THREE.MeshLambertMaterial({ color: new THREE.Color().setHSL(leafHue + 0.03, leafSatA * 0.9, 0.27 + rng() * 0.07) });

    for (let i = 0; i < numLayers; i++) {
      const t      = i / (numLayers - 1);
      const coneR  = (2.4 - t * 1.4) * (0.75 + rng() * 0.5);
      const coneH  = (2.8 - t * 0.9) * (0.7 + rng() * 0.45);
      const yPos   = trunkH * 0.3 + t * trunkH * 0.78;
      const cone   = new THREE.Mesh(new THREE.ConeGeometry(coneR, coneH, 9), i % 2 === 0 ? matA : matB);
      cone.position.set(
        (rng() - 0.5) * 0.28,
        yPos,
        (rng() - 0.5) * 0.28
      );
      cone.rotation.y = rng() * Math.PI;
      cone.castShadow = true;
      grp.add(cone);
    }

    // 4 side branches with leaf balls
    for (let b = 0; b < 4; b++) {
      const angle  = (b / 4) * Math.PI * 2 + rng() * 0.8;
      const brY    = trunkH * (0.32 + rng() * 0.32);
      const brLen  = 1.1 + rng() * 1.0;
      const branch = new THREE.Mesh(
        new THREE.CylinderGeometry(0.035, 0.07, brLen, 6),
        barkMat
      );
      branch.position.set(Math.cos(angle) * brLen * 0.38, brY, Math.sin(angle) * brLen * 0.38);
      branch.rotation.set(Math.sin(angle) * 0.65, 0, -Math.cos(angle) * 0.65);
      branch.castShadow = true;
      grp.add(branch);

      const leafBall = new THREE.Mesh(
        new THREE.SphereGeometry(0.5 + rng() * 0.4, 6, 5),
        rng() > 0.5 ? matA : matB
      );
      leafBall.position.set(Math.cos(angle) * brLen * 0.85, brY + 0.4, Math.sin(angle) * brLen * 0.85);
      leafBall.castShadow = true;
      grp.add(leafBall);
    }

    // Some trees get hanging moss (thin cylinder strands) in forest biome
    if (rng() > 0.6) {
      const mossMat = new THREE.MeshLambertMaterial({ color: 0x2d5a27 });
      for (let m = 0; m < 3; m++) {
        const mossLen = 0.4 + rng() * 0.6;
        const moss = new THREE.Mesh(new THREE.CylinderGeometry(0.015, 0.01, mossLen, 4), mossMat);
        moss.position.set(
          (rng() - 0.5) * trunkH * 0.4,
          trunkH * (0.5 + rng() * 0.4),
          (rng() - 0.5) * trunkH * 0.4
        );
        grp.add(moss);
      }
    }

    grp.position.set(wx, h, wz);
    grp.rotation.y = rng() * Math.PI * 2;
    grp.scale.setScalar(0.82 + rng() * 0.38);
    this.scene.add(grp);

    return {
      type: 'tree', mesh: grp,
      position: new THREE.Vector3(wx, h, wz),
      health: 100, maxHealth: 100,
      resources: { wood: 4 + Math.floor(rng() * 4) },
      depleted: false, respawnTimer: 0,
    };
  }

  // ── Detailed Rock cluster ─────────────────────────────────────────────────
  _makeRock(wx, h, wz, rng, biome) {
    const grp = new THREE.Group();
    grp.position.set(wx, h, wz);

    const roll   = rng();
    const isHigh = biome === 'mountain' || biome === 'highland';
    let matKey;
    if      (isHigh && rng() > 0.7) matKey = 'rockSnow';
    else if (roll < 0.52) matKey = 'rock';
    else if (roll < 0.78) matKey = 'rockCoal';
    else                  matKey = 'rockIron';

    const mat    = this.mats[matKey];
    const scale  = 0.55 + rng() * 1.0;

    // Main rock — deformed icosahedron for natural look
    const geo = new THREE.IcosahedronGeometry(scale, 1);
    const pA  = geo.attributes.position;
    for (let i = 0; i < pA.count; i++) {
      const nx = pA.getX(i), ny = pA.getY(i), nz = pA.getZ(i);
      pA.setX(i, nx * (0.72 + rng() * 0.56));
      pA.setY(i, ny * (0.48 + rng() * 0.52));
      pA.setZ(i, nz * (0.72 + rng() * 0.56));
    }
    pA.needsUpdate = true;
    geo.computeVertexNormals();
    const main = new THREE.Mesh(geo, mat);
    main.position.y = scale * 0.38;
    main.rotation.set(rng() * 0.55, rng() * Math.PI * 2, rng() * 0.55);
    main.castShadow = true;
    grp.add(main);

    // Flat slab under main rock
    const slab = new THREE.Mesh(
      new THREE.CylinderGeometry(scale * 0.9, scale * 1.1, 0.18, 8),
      mat
    );
    slab.position.y = 0.05;
    grp.add(slab);

    // 2-4 satellite rocks
    const nExtra = 2 + Math.floor(rng() * 3);
    for (let i = 0; i < nExtra; i++) {
      const es   = scale * (0.18 + rng() * 0.42);
      const eg   = new THREE.IcosahedronGeometry(es, rng() > 0.5 ? 1 : 0);
      const ePos = eg.attributes.position;
      for (let j = 0; j < ePos.count; j++) {
        ePos.setX(j, ePos.getX(j) * (0.7 + rng() * 0.6));
        ePos.setY(j, ePos.getY(j) * (0.5 + rng() * 0.5));
        ePos.setZ(j, ePos.getZ(j) * (0.7 + rng() * 0.6));
      }
      ePos.needsUpdate = true;
      eg.computeVertexNormals();
      const extra = new THREE.Mesh(eg, mat);
      const ang   = (i / nExtra) * Math.PI * 2 + rng();
      extra.position.set(
        Math.cos(ang) * scale * (0.65 + rng() * 0.5),
        es * 0.3,
        Math.sin(ang) * scale * (0.65 + rng() * 0.5)
      );
      extra.rotation.set(rng() * 0.8, rng() * Math.PI * 2, rng() * 0.8);
      extra.castShadow = true;
      grp.add(extra);
    }

    // Dirt/grass ring at base (flat ring geometry)
    const ringMat = new THREE.MeshLambertMaterial({ color: 0x3a3020 });
    const ring    = new THREE.Mesh(new THREE.RingGeometry(scale * 0.9, scale * 1.6, 10), ringMat);
    ring.rotation.x = -Math.PI / 2;
    ring.position.y = 0.01;
    grp.add(ring);

    this.scene.add(grp);

    const resources = matKey === 'rock'     ? { stone: 4 + Math.floor(rng() * 4) }
                    : matKey === 'rockCoal'  ? { stone: 2, coal: 3 + Math.floor(rng() * 3) }
                    : matKey === 'rockSnow'  ? { stone: 5, iron: 1 }
                    :                          { stone: 2, iron: 2 + Math.floor(rng() * 3) };

    return {
      type: 'rock', mesh: grp,
      position: new THREE.Vector3(wx, h, wz),
      health: 100, maxHealth: 100,
      resources, depleted: false, respawnTimer: 0,
    };
  }

  // ── Detailed Bush ─────────────────────────────────────────────────────────
  _makeBush(wx, h, wz, rng) {
    const grp = new THREE.Group();
    grp.position.set(wx, h, wz);

    const count  = 3 + Math.floor(rng() * 3);
    const bushH  = rng() > 0.5 ? 0.27 : 0.33; // hue – green or amber (berries)
    const bushMat = new THREE.MeshLambertMaterial({
      color: new THREE.Color().setHSL(bushH, 0.6 + rng() * 0.25, 0.22 + rng() * 0.1),
    });
    const berryMat = new THREE.MeshLambertMaterial({ color: 0xcc2244 });

    for (let i = 0; i < count; i++) {
      const r = 0.35 + rng() * 0.4;
      const sphere = new THREE.Mesh(new THREE.SphereGeometry(r, 7, 6), bushMat);
      sphere.position.set((rng() - 0.5) * 0.7, r * 0.7, (rng() - 0.5) * 0.7);
      sphere.scale.y = 0.75 + rng() * 0.3;
      sphere.castShadow = true;
      grp.add(sphere);

      // Small berry dots
      if (rng() > 0.5) {
        for (let b = 0; b < 4; b++) {
          const berry = new THREE.Mesh(new THREE.SphereGeometry(0.07, 4, 4), berryMat);
          berry.position.set(
            sphere.position.x + (rng() - 0.5) * r,
            sphere.position.y + (rng() - 0.5) * r * 0.5 + r * 0.4,
            sphere.position.z + (rng() - 0.5) * r
          );
          grp.add(berry);
        }
      }
    }

    this.scene.add(grp);
    return {
      type: 'bush', mesh: grp,
      position: new THREE.Vector3(wx, h, wz),
      health: 20, maxHealth: 20,
      resources: { berries: 2 + Math.floor(rng() * 3) },
      depleted: false, respawnTimer: 30,
    };
  }

  // ── Public API ────────────────────────────────────────────────────────────
  getGroundHeight(wx, wz) { return this.getHeight(wx, wz); }

  getNearestNode(pos, maxDist = 3.5) {
    let best = null, bestD = Infinity;
    for (const n of this.resourceNodes) {
      if (n.depleted) continue;
      const dx = n.position.x - pos.x, dz = n.position.z - pos.z;
      const d  = Math.sqrt(dx * dx + dz * dz);
      if (d < maxDist && d < bestD) { bestD = d; best = n; }
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
    // Respawn nodes
    for (const n of this.resourceNodes) {
      if (!n.depleted) continue;
      n.respawnTimer -= dt;
      if (n.respawnTimer <= 0) {
        n.depleted = false;
        n.health   = n.maxHealth;
        if (n.mesh) n.mesh.visible = true;
      }
    }
    // Gentle water animation
    this._waterTime += dt * 0.4;
    if (this._waterMesh) this._waterMesh.position.y = CONFIG.SEA_LEVEL - 0.25 + Math.sin(this._waterTime) * 0.08;
  }

  getRaycastObjects() {
    const objs = [];
    for (const [, c] of this.chunks) objs.push(c.mesh);
    return objs;
  }
}
