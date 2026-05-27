// Cyber Road Racer – Three.js r128
(function () {
  'use strict';

  const LANE_X     = [-3, 0, 3];
  const ROAD_W     = 10;
  const SEG_LEN    = 20;
  const NUM_SEGS   = 8;
  const SPAWN_Z    = -72;
  const DESPAWN_Z  = 13;
  const BASE_SPEED = 0.18;
  const MAX_SPEED  = 0.80;
  const SPEED_INC  = 0.000025;

  let scene, camera, renderer;
  let playerGroup;
  let roadSegs = [], obstacles = [];
  let frame = 0, score = 0, lives = 3;
  let speed = BASE_SPEED;
  let targetLane = 1, invFrames = 0;
  let running = false;

  /* ── Init ──────────────────────────────────────────────────── */
  function init() {
    const canvas = document.getElementById('racing-canvas');

    renderer = new THREE.WebGLRenderer({ canvas, antialias: true });
    renderer.setPixelRatio(Math.min(devicePixelRatio, 2));
    onResize();

    scene = new THREE.Scene();
    scene.background = new THREE.Color(0x04020f);
    scene.fog = new THREE.FogExp2(0x04020f, 0.015);

    camera = new THREE.PerspectiveCamera(68, 1, 0.1, 200);
    camera.position.set(0, 4.5, 10);
    camera.lookAt(0, 0.5, -3);

    scene.add(new THREE.AmbientLight(0x2a1060, 3.5));
    const dir = new THREE.DirectionalLight(0xaa88ff, 1.2);
    dir.position.set(0, 20, 10);
    scene.add(dir);

    buildStars();
    buildRoad();
    buildPlayer();
    buildSideDecos();

    window.addEventListener('resize', onResize);
    document.addEventListener('keydown', onKey);
    setupTouch();
  }

  function onResize() {
    const canvas = document.getElementById('racing-canvas');
    const w = canvas.clientWidth;
    const h = canvas.clientHeight || 520;
    renderer.setSize(w, h, false);
    if (camera) { camera.aspect = w / h; camera.updateProjectionMatrix(); }
  }

  /* ── Helpers ───────────────────────────────────────────────── */
  function mkMesh(geo, mat, x, y, z) {
    const m = new THREE.Mesh(geo, mat);
    m.position.set(x, y, z);
    return m;
  }

  /* ── Scene builders ────────────────────────────────────────── */
  function buildStars() {
    const pos = [];
    for (let i = 0; i < 1000; i++) {
      pos.push(
        (Math.random() - 0.5) * 260,
        8 + Math.random() * 55,
        (Math.random() - 0.5) * 260
      );
    }
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
    scene.add(new THREE.Points(g, new THREE.PointsMaterial({ color: 0xffffff, size: 0.2 })));
  }

  function buildRoad() {
    const roadMat = new THREE.MeshLambertMaterial({ color: 0x0d0824 });
    const dashMat = new THREE.MeshLambertMaterial({ color: 0xffffff, emissive: 0xffffff, emissiveIntensity: 0.3 });
    const edgeMat = new THREE.MeshLambertMaterial({ color: 0x9333ea, emissive: 0x9333ea, emissiveIntensity: 1.0 });

    for (let i = 0; i < NUM_SEGS; i++) {
      const grp = new THREE.Group();

      grp.add(mkMesh(new THREE.BoxGeometry(ROAD_W, 0.12, SEG_LEN), roadMat, 0, 0, 0));

      for (let ln = 0; ln < 2; ln++) {
        const lx = ln === 0 ? -1.5 : 1.5;
        for (let d = 0; d < 5; d++) {
          grp.add(mkMesh(new THREE.BoxGeometry(0.1, 0.13, 2.5), dashMat, lx, 0.12, (d - 2) * 3.8));
        }
      }

      grp.add(mkMesh(new THREE.BoxGeometry(0.14, 0.32, SEG_LEN), edgeMat, -(ROAD_W / 2 - 0.07), 0.2, 0));
      grp.add(mkMesh(new THREE.BoxGeometry(0.14, 0.32, SEG_LEN), edgeMat,  (ROAD_W / 2 - 0.07), 0.2, 0));

      grp.position.z = -i * SEG_LEN;
      roadSegs.push(grp);
      scene.add(grp);
    }
  }

  function buildCarMesh(bodyCol, emitCol) {
    const grp  = new THREE.Group();
    const bMat = new THREE.MeshLambertMaterial({ color: bodyCol, emissive: emitCol, emissiveIntensity: 0.5 });
    const gMat = new THREE.MeshLambertMaterial({ color: 0x99ccff, transparent: true, opacity: 0.6 });
    const wMat = new THREE.MeshLambertMaterial({ color: 0x222233 });
    const hMat = new THREE.MeshLambertMaterial({ color: 0xffffaa, emissive: 0xffffaa, emissiveIntensity: 1.5 });
    const tMat = new THREE.MeshLambertMaterial({ color: 0xff2200, emissive: 0xff2200, emissiveIntensity: 1.5 });

    grp.add(mkMesh(new THREE.BoxGeometry(1.5, 0.55, 3.0), bMat, 0, 0.38, 0));
    grp.add(mkMesh(new THREE.BoxGeometry(1.15, 0.48, 1.6), bMat, 0, 0.9, -0.1));

    const ws = mkMesh(new THREE.BoxGeometry(1.1, 0.38, 0.06), gMat, 0, 0.87, 0.68);
    ws.rotation.x = -0.35; grp.add(ws);
    const rw = mkMesh(new THREE.BoxGeometry(1.1, 0.38, 0.06), gMat, 0, 0.87, -0.94);
    rw.rotation.x = 0.35; grp.add(rw);

    const wGeo = new THREE.CylinderGeometry(0.3, 0.3, 0.22, 10);
    const wheels = [];
    [[-0.85, 0.3, 0.95], [0.85, 0.3, 0.95], [-0.85, 0.3, -0.95], [0.85, 0.3, -0.95]].forEach(function (p) {
      const w = mkMesh(wGeo, wMat, p[0], p[1], p[2]);
      w.rotation.z = Math.PI / 2;
      wheels.push(w);
      grp.add(w);
    });
    grp.userData.wheels = wheels;

    [[-0.42, 0.42, 1.51], [0.42, 0.42, 1.51]].forEach(function (p) {
      grp.add(mkMesh(new THREE.BoxGeometry(0.3, 0.15, 0.04), hMat, p[0], p[1], p[2]));
    });
    [[-0.42, 0.42, -1.51], [0.42, 0.42, -1.51]].forEach(function (p) {
      grp.add(mkMesh(new THREE.BoxGeometry(0.3, 0.15, 0.04), tMat, p[0], p[1], p[2]));
    });

    return grp;
  }

  function buildPlayer() {
    playerGroup = buildCarMesh(0x00ccee, 0x0099cc);
    playerGroup.position.set(0, 0, 3);
    scene.add(playerGroup);

    const pl = new THREE.PointLight(0x00ffff, 2.5, 11);
    pl.position.set(0, 2, 0);
    playerGroup.add(pl);
  }

  function buildSideDecos() {
    const poleMat = new THREE.MeshLambertMaterial({ color: 0x2a1a4a });
    const bulbMat = new THREE.MeshLambertMaterial({ color: 0xcc88ff, emissive: 0xcc88ff, emissiveIntensity: 1.2 });

    for (let z = -120; z <= 12; z += 18) {
      [-7.5, 7.5].forEach(function (x) {
        scene.add(mkMesh(new THREE.CylinderGeometry(0.1, 0.12, 4.5, 6), poleMat, x, 2.25, z));
        scene.add(mkMesh(new THREE.SphereGeometry(0.22, 6, 6), bulbMat, x, 4.6, z));
        if ((z + 120) % 36 === 0) {
          const pl = new THREE.PointLight(0xcc88ff, 0.85, 10);
          pl.position.set(x, 4.4, z);
          scene.add(pl);
        }
      });
    }
  }

  /* ── Obstacle spawning ─────────────────────────────────────── */
  function spawnObstacle() {
    const lane = Math.floor(Math.random() * 3);
    const COLS = [0xee2244, 0xff6600, 0xcc33ff, 0xffcc00, 0x00ee66];
    const c    = COLS[Math.floor(Math.random() * COLS.length)];
    const car  = buildCarMesh(c, c);
    car.position.set(LANE_X[lane], 0, SPAWN_Z);
    car.rotation.y = Math.PI;
    obstacles.push({ mesh: car, lane: lane });
    scene.add(car);
  }

  /* ── Controls ──────────────────────────────────────────────── */
  function onKey(e) {
    if (!running) return;
    if ((e.key === 'ArrowLeft'  || e.key === 'a' || e.key === 'A') && targetLane > 0) targetLane--;
    if ((e.key === 'ArrowRight' || e.key === 'd' || e.key === 'D') && targetLane < 2) targetLane++;
  }

  function setupTouch() {
    var sx = 0;
    var canvas = document.getElementById('racing-canvas');
    canvas.addEventListener('touchstart', function (e) { sx = e.touches[0].clientX; }, { passive: true });
    canvas.addEventListener('touchend', function (e) {
      if (!running) return;
      var dx = e.changedTouches[0].clientX - sx;
      if (dx < -40 && targetLane > 0) targetLane--;
      if (dx >  40 && targetLane < 2) targetLane++;
    }, { passive: true });
  }

  /* ── Collision ─────────────────────────────────────────────── */
  function collides() {
    var px = playerGroup.position.x;
    var pz = playerGroup.position.z;
    for (var i = 0; i < obstacles.length; i++) {
      var o = obstacles[i];
      if (Math.abs(px - o.mesh.position.x) < 1.4 &&
          Math.abs(pz - o.mesh.position.z) < 2.5) return true;
    }
    return false;
  }

  /* ── HUD ───────────────────────────────────────────────────── */
  function updateHUD() {
    document.getElementById('r-score').textContent = Math.floor(score);
    document.getElementById('r-speed').textContent = Math.floor(80 + speed * 500) + ' KM/H';
    var h = '';
    for (var i = 0; i < 3; i++) h += i < lives ? '❤️' : '🖤';
    document.getElementById('r-lives').textContent = h;
  }

  /* ── Game loop ─────────────────────────────────────────────── */
  function loop() {
    if (!running) return;
    requestAnimationFrame(loop);
    frame++;

    speed = Math.min(MAX_SPEED, BASE_SPEED + frame * SPEED_INC);
    score += speed;

    // Smooth lane change + body tilt
    var tx = LANE_X[targetLane];
    playerGroup.position.x += (tx - playerGroup.position.x) * 0.13;
    playerGroup.rotation.z += (-(tx - playerGroup.position.x) * 0.18 - playerGroup.rotation.z) * 0.18;

    // Spin player wheels
    playerGroup.userData.wheels.forEach(function (w) { w.rotation.x += speed * 2; });

    // Scroll road segments (recycle when past camera)
    for (var s = 0; s < roadSegs.length; s++) {
      roadSegs[s].position.z += speed;
      if (roadSegs[s].position.z > DESPAWN_Z + SEG_LEN / 2) {
        var minZ = Infinity;
        for (var k = 0; k < roadSegs.length; k++) {
          if (roadSegs[k].position.z < minZ) minZ = roadSegs[k].position.z;
        }
        roadSegs[s].position.z = minZ - SEG_LEN + speed;
      }
    }

    // Move obstacles toward player
    for (var i = obstacles.length - 1; i >= 0; i--) {
      var o = obstacles[i];
      o.mesh.position.z += speed;
      if (o.mesh.userData.wheels) {
        o.mesh.userData.wheels.forEach(function (w) { w.rotation.x += speed * 2; });
      }
      if (o.mesh.position.z > DESPAWN_Z) {
        scene.remove(o.mesh);
        obstacles.splice(i, 1);
      }
    }

    // Spawn new obstacles (gap shrinks over time)
    var gap = Math.max(45, 95 - Math.floor(frame / 200));
    if (frame % gap === 0) spawnObstacle();

    // Invincibility blink after hit
    if (invFrames > 0) {
      invFrames--;
      playerGroup.visible = Math.floor(invFrames / 6) % 2 === 0;
      if (invFrames === 0) playerGroup.visible = true;
    } else if (collides()) {
      lives--;
      if (window._spawnSparks) window._spawnSparks(innerWidth / 2, innerHeight * 0.6, 30);
      if (lives <= 0) { endGame(); return; }
      invFrames = 150;
    }

    // Camera gently tracks player X
    camera.position.x += (playerGroup.position.x * 0.25 - camera.position.x) * 0.06;

    updateHUD();
    renderer.render(scene, camera);
  }

  /* ── Public API ────────────────────────────────────────────── */
  window.startRacing = function () {
    frame = 0; score = 0; lives = 3; speed = BASE_SPEED;
    targetLane = 1; invFrames = 0;

    playerGroup.position.set(0, 0, 3);
    playerGroup.rotation.set(0, 0, 0);
    playerGroup.visible = true;

    obstacles.forEach(function (o) { scene.remove(o.mesh); });
    obstacles = [];
    roadSegs.forEach(function (s, i) { s.position.z = -i * SEG_LEN; });

    document.getElementById('r-start').classList.add('hidden');
    document.getElementById('r-over').classList.add('hidden');

    running = true;
    loop();
  };

  function endGame() {
    running = false;
    playerGroup.visible = true;

    fetch('/api/submit_score', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ score: Math.floor(score), source: 'racing', difficulty: '' }),
    })
      .then(function (r) { return r.json(); })
      .then(function (d) {
        if (d.memory_unlocked) document.getElementById('r-unlock').style.display = 'block';
      })
      .catch(function () {});

    document.getElementById('r-final').textContent = Math.floor(score);
    document.getElementById('r-over').classList.remove('hidden');
  }

  /* ── Boot on load ──────────────────────────────────────────── */
  window.addEventListener('load', function () {
    init();
    renderer.render(scene, camera);
  });
})();
