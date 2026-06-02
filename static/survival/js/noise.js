'use strict';

class SimplexNoise {
  constructor(seed) {
    const grad3 = [
      [1,1,0],[-1,1,0],[1,-1,0],[-1,-1,0],
      [1,0,1],[-1,0,1],[1,0,-1],[-1,0,-1],
      [0,1,1],[0,-1,1],[0,1,-1],[0,-1,-1]
    ];
    this.grad3 = grad3;

    const p = Array.from({ length: 256 }, (_, i) => i);
    let s = (seed | 0) >>> 0 || 12345;
    const rng = () => { s = (Math.imul(s, 1664525) + 1013904223) >>> 0; return s / 0x100000000; };
    for (let i = 255; i > 0; i--) {
      const j = Math.floor(rng() * (i + 1));
      [p[i], p[j]] = [p[j], p[i]];
    }

    this.perm     = new Uint8Array(512);
    this.permM12  = new Uint8Array(512);
    for (let i = 0; i < 512; i++) {
      this.perm[i]    = p[i & 255];
      this.permM12[i] = this.perm[i] % 12;
    }
  }

  _dot(g, x, y) { return g[0] * x + g[1] * y; }

  noise2D(xin, yin) {
    const { grad3: g3, perm, permM12 } = this;
    const F2 = 0.5 * (Math.sqrt(3) - 1);
    const G2 = (3 - Math.sqrt(3)) / 6;

    const s  = (xin + yin) * F2;
    const i  = Math.floor(xin + s);
    const j  = Math.floor(yin + s);
    const t  = (i + j) * G2;
    const x0 = xin - (i - t);
    const y0 = yin - (j - t);

    const i1 = x0 > y0 ? 1 : 0;
    const j1 = x0 > y0 ? 0 : 1;

    const x1 = x0 - i1 + G2, y1 = y0 - j1 + G2;
    const x2 = x0 - 1 + 2 * G2, y2 = y0 - 1 + 2 * G2;

    const ii = i & 255, jj = j & 255;
    const gi0 = permM12[ii       + perm[jj]];
    const gi1 = permM12[ii + i1  + perm[jj + j1]];
    const gi2 = permM12[ii + 1   + perm[jj + 1]];

    const t0 = 0.5 - x0*x0 - y0*y0;
    const t1 = 0.5 - x1*x1 - y1*y1;
    const t2 = 0.5 - x2*x2 - y2*y2;

    const n0 = t0 < 0 ? 0 : ((t0*t0) * (t0*t0)) * this._dot(g3[gi0], x0, y0);
    const n1 = t1 < 0 ? 0 : ((t1*t1) * (t1*t1)) * this._dot(g3[gi1], x1, y1);
    const n2 = t2 < 0 ? 0 : ((t2*t2) * (t2*t2)) * this._dot(g3[gi2], x2, y2);

    return 70 * (n0 + n1 + n2); // range ≈ [-1, 1]
  }

  // Fractional Brownian Motion — returns value roughly in [-1, 1]
  fbm(x, y, octaves = 6, persistence = 0.5, lacunarity = 2.0) {
    let v = 0, amp = 1, freq = 1, maxV = 0;
    for (let i = 0; i < octaves; i++) {
      v    += this.noise2D(x * freq, y * freq) * amp;
      maxV += amp;
      amp  *= persistence;
      freq *= lacunarity;
    }
    return v / maxV;
  }
}
