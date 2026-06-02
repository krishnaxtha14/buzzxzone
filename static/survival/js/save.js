'use strict';

class SaveSystem {
  constructor(game) {
    this.game = game;
    this._saving = false;
  }

  async saveGame(auto = false) {
    if (this._saving) return;
    this._saving = true;

    const data = {
      player:     this.game.player.getState(),
      inventory:  this.game.inventory.getState(),
      environment: this.game.environment.getState(),
      structures: this.game.building.getStructures().map(s => ({
        type:     s.type,
        position: { x: s.position.x, y: s.position.y, z: s.position.z },
        rotation: s.rotation,
      })),
      dayNumber:    this.game.dayNumber,
      survivalTime: this.game.survivalTime,
      savedAt:      new Date().toISOString(),
    };

    try {
      const resp = await fetch('/api/survival/save', {
        method:  'POST',
        headers: { 'Content-Type': 'application/json' },
        body:    JSON.stringify(data),
      });
      const json = await resp.json();
      if (json.ok) {
        if (!auto) this.game.ui.notify('Game saved!', 'success');
      } else {
        this.game.ui.notify('Save failed: ' + (json.error || 'unknown'), 'error');
      }
    } catch (e) {
      this.game.ui.notify('Save error: ' + e.message, 'error');
    } finally {
      this._saving = false;
    }
  }

  async loadGame() {
    try {
      const resp = await fetch('/api/survival/load');
      const json = await resp.json();
      if (json.ok && json.data) return json.data;
      return null;
    } catch (e) {
      console.error('Load error:', e);
      return null;
    }
  }
}
