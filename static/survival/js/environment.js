'use strict';

const WEATHER = { CLEAR: 'clear', CLOUDY: 'cloudy', RAIN: 'rain', FOG: 'fog' };

class EnvironmentSystem {
  constructor(game) {
    this.game = game;

    // Time: 0 = midnight, 360 = 6AM, 720 = noon, 1080 = 6PM, 1440 = midnight
    this._time = 360;                 // start at 6 AM
    this._totalDayTime = CONFIG.DAY_DURATION + CONFIG.NIGHT_DURATION;
    this._dayNumber = 1;

    this._weather = WEATHER.CLEAR;
    this._weatherTimer = CONFIG.WEATHER_INTERVAL;
    this._rainParticles = null;
    this._rainActive = false;

    this._setupLights();
    this._setupSky();
    this._setupRain();
  }

  _setupLights() {
    // Ambient
    this._ambient = new THREE.AmbientLight(0x404060, 0.4);
    this.game.scene.add(this._ambient);

    // Hemisphere (sky/ground gradient)
    this._hemi = new THREE.HemisphereLight(0x87ceeb, 0x2d5016, 0.6);
    this.game.scene.add(this._hemi);

    // Directional sun/moon
    this._sun = new THREE.DirectionalLight(0xffeedd, 1.2);
    this._sun.castShadow = true;
    this._sun.shadow.mapSize.set(1024, 1024);
    this._sun.shadow.camera.near = 0.5;
    this._sun.shadow.camera.far  = 200;
    this._sun.shadow.camera.left   = -80;
    this._sun.shadow.camera.right  =  80;
    this._sun.shadow.camera.top    =  80;
    this._sun.shadow.camera.bottom = -80;
    this.game.scene.add(this._sun);

    // Moon (dim blue-white)
    this._moon = new THREE.DirectionalLight(0xaaaacc, 0.25);
    this.game.scene.add(this._moon);
  }

  _setupSky() {
    // Simple sky sphere
    const geo  = new THREE.SphereGeometry(400, 16, 12);
    const mat  = new THREE.MeshBasicMaterial({ color: 0x87ceeb, side: THREE.BackSide });
    this._sky  = new THREE.Mesh(geo, mat);
    this.game.scene.add(this._sky);
  }

  _setupRain() {
    const count = 3000;
    const geo   = new THREE.BufferGeometry();
    const pos   = new Float32Array(count * 3);
    for (let i = 0; i < count; i++) {
      pos[i * 3]     = (Math.random() - 0.5) * 80;
      pos[i * 3 + 1] = Math.random() * 50;
      pos[i * 3 + 2] = (Math.random() - 0.5) * 80;
    }
    geo.setAttribute('position', new THREE.BufferAttribute(pos, 3));
    const mat = new THREE.PointsMaterial({ color: 0x8888cc, size: 0.08, transparent: true, opacity: 0.6 });
    this._rainParticles = new THREE.Points(geo, mat);
    this._rainParticles.visible = false;
    this.game.scene.add(this._rainParticles);
  }

  setTime(minutes) { this._time = minutes % 1440; }

  getTimeMinutes() { return this._time; }

  isNight() {
    return this._time < 300 || this._time > 1140; // 5AM–7PM is day
  }

  _timeString() {
    const h   = Math.floor(this._time / 60) % 24;
    const m   = Math.floor(this._time % 60);
    return `${String(h).padStart(2,'0')}:${String(m).padStart(2,'0')}`;
  }

  update(dt) {
    // Advance time
    const realSec = dt;
    const gameMin = realSec * (1440 / this._totalDayTime);
    this._time += gameMin;

    if (this._time >= 1440) {
      this._time -= 1440;
      this._dayNumber++;
      this.game.dayNumber = this._dayNumber;
    }

    this._updateLighting();
    this._updateWeather(dt);
    this._updateRain(dt);
    this._updateTimeDisplay();
  }

  _updateLighting() {
    const t = this._time;

    // Sun angle: rises at t=360 (6AM), peaks at t=720 (noon), sets at t=1080 (6PM)
    const dayProgress = (t - 360) / 720; // 0..1 during day
    const sunAngle    = dayProgress * Math.PI;
    const sunHeight   = Math.sin(sunAngle);
    const sunSide     = Math.cos(sunAngle);

    this._sun.position.set(sunSide * 100, sunHeight * 80, -30);
    this._moon.position.set(-sunSide * 100, -sunHeight * 80 + 50, 30);

    // Sky + lighting colors
    let skyColor, ambIntensity, sunIntensity, fogColor;

    if (t < 300 || t > 1200) {
      // Deep night
      skyColor     = new THREE.Color(0x050510);
      ambIntensity = 0.1;
      sunIntensity = 0;
      this._moon.intensity = 0.3;
      fogColor = new THREE.Color(0x050510);
    } else if (t < 360) {
      // Dawn
      const p = (t - 300) / 60;
      skyColor     = new THREE.Color().lerpColors(new THREE.Color(0x050510), new THREE.Color(0xff7744), p);
      ambIntensity = 0.1 + p * 0.3;
      sunIntensity = p * 0.5;
      this._moon.intensity = 0.3 - p * 0.25;
      fogColor = skyColor.clone();
    } else if (t < 420) {
      // Sunrise
      const p = (t - 360) / 60;
      skyColor     = new THREE.Color().lerpColors(new THREE.Color(0xff7744), new THREE.Color(0x87ceeb), p);
      ambIntensity = 0.4 + p * 0.2;
      sunIntensity = 0.5 + p * 0.7;
      this._moon.intensity = 0.05;
      fogColor = skyColor.clone();
    } else if (t < 1080) {
      // Full day
      const peak   = Math.sin(((t - 420) / 660) * Math.PI);
      skyColor     = new THREE.Color().lerpColors(new THREE.Color(0x87ceeb), new THREE.Color(0x5ab8f5), peak * 0.3);
      ambIntensity = 0.6 + peak * 0.2;
      sunIntensity = 1.0 + peak * 0.4;
      this._moon.intensity = 0;
      fogColor = new THREE.Color(0x87ceeb);
    } else if (t < 1140) {
      // Sunset
      const p = (t - 1080) / 60;
      skyColor     = new THREE.Color().lerpColors(new THREE.Color(0x87ceeb), new THREE.Color(0xff5522), p);
      ambIntensity = 0.6 - p * 0.4;
      sunIntensity = 1.0 - p * 0.8;
      this._moon.intensity = p * 0.2;
      fogColor = skyColor.clone();
    } else {
      // Evening → night
      const p = (t - 1140) / 60;
      skyColor     = new THREE.Color().lerpColors(new THREE.Color(0xff5522), new THREE.Color(0x050510), p);
      ambIntensity = 0.2 - p * 0.1;
      sunIntensity = 0.2 - p * 0.2;
      this._moon.intensity = 0.2 + p * 0.1;
      fogColor = skyColor.clone();
    }

    this._sky.material.color.copy(skyColor);
    this._ambient.intensity       = Math.max(0.08, ambIntensity);
    this._sun.intensity           = Math.max(0, sunIntensity);
    this.game.scene.fog.color.copy(fogColor);
    this.game.renderer.setClearColor(skyColor);

    // Sun color (warm at day, orange at sunrise/set)
    if (t >= 420 && t <= 1080) this._sun.color.setHex(0xfff5dd);
    else this._sun.color.setHex(0xff9944);
  }

  _updateWeather(dt) {
    this._weatherTimer -= dt;
    if (this._weatherTimer > 0) return;
    this._weatherTimer = CONFIG.WEATHER_INTERVAL + Math.random() * 120;

    const weathers = [WEATHER.CLEAR, WEATHER.CLEAR, WEATHER.CLEAR, WEATHER.CLOUDY, WEATHER.RAIN, WEATHER.FOG];
    this._weather  = weathers[Math.floor(Math.random() * weathers.length)];

    switch (this._weather) {
      case WEATHER.CLEAR:
        this.game.scene.fog.far = 200;
        this._rainActive = false;
        break;
      case WEATHER.CLOUDY:
        this.game.scene.fog.far = 150;
        this._rainActive = false;
        this.game.ui.notify('Clouds rolling in...', 'info');
        break;
      case WEATHER.RAIN:
        this.game.scene.fog.far = 80;
        this._rainActive = true;
        this.game.ui.notify('It starts to rain...', 'info');
        break;
      case WEATHER.FOG:
        this.game.scene.fog.far = 40;
        this._rainActive = false;
        this.game.ui.notify('Dense fog rolls in...', 'info');
        break;
    }
  }

  _updateRain(dt) {
    if (!this._rainParticles) return;
    this._rainParticles.visible = this._rainActive;
    if (!this._rainActive) return;

    const playerPos = this.game.player.getPosition();
    this._rainParticles.position.set(playerPos.x, playerPos.y, playerPos.z);

    const pos = this._rainParticles.geometry.attributes.position;
    for (let i = 0; i < pos.count; i++) {
      pos.setY(i, pos.getY(i) - 20 * dt);
      if (pos.getY(i) < -5) pos.setY(i, 45);
    }
    pos.needsUpdate = true;

    // Rain increases thirst drain — handled by weather state
    if (this.game.state === 'playing') {
      this.game.player.thirst = Math.min(CONFIG.MAX_THIRST, this.game.player.thirst + 0.3 * dt);
    }
  }

  _updateTimeDisplay() {
    const el = document.getElementById('time-display');
    if (!el) return;
    const icon = this.isNight() ? '🌙' : (this._time < 420 || this._time > 1080 ? '🌅' : '☀️');
    el.textContent = `${icon} Day ${this._dayNumber} · ${this._timeString()}`;
  }

  getState() {
    return { time: this._time, day: this._dayNumber, weather: this._weather };
  }
}
