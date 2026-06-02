'use strict';

class InventorySystem {
  constructor(game) {
    this.game = game;

    // Grid: 5 rows × 6 cols = 30 slots
    const total = CONFIG.INV_ROWS * CONFIG.INV_COLS;
    this.slots   = Array(total).fill(null);          // { id, qty }
    this.hotbar  = Array(CONFIG.HOTBAR_SLOTS).fill(null);
    this.equip   = { weapon: null, head: null, chest: null, legs: null, feet: null };
    this.hotbarSelected = 0;

    this._dragging       = null;  // { source, index, item }
    this._dragEl         = null;
    this._selectedRecipe = null;

    this._open = false;
    this._buildDOM();
    this._bindDragEvents();
  }

  // ── DOM ──────────────────────────────────────────────────────────────────────
  _buildDOM() {
    // Inventory grid (30 slots)
    const grid = document.getElementById('inv-grid');
    grid.innerHTML = '';
    for (let i = 0; i < CONFIG.INV_ROWS * CONFIG.INV_COLS; i++) {
      const sl = document.createElement('div');
      sl.className = 'inv-slot';
      sl.dataset.source = 'inv';
      sl.dataset.index  = i;
      grid.appendChild(sl);
    }

    // Hotbar (9 slots in inventory panel)
    const hb = document.getElementById('inv-hotbar');
    hb.innerHTML = '';
    for (let i = 0; i < CONFIG.HOTBAR_SLOTS; i++) {
      const sl = document.createElement('div');
      sl.className = 'inv-slot';
      sl.dataset.source = 'hotbar';
      sl.dataset.index  = i;
      hb.appendChild(sl);
    }

    // HUD Hotbar
    const hudHb = document.getElementById('hotbar');
    hudHb.innerHTML = '';
    for (let i = 0; i < CONFIG.HOTBAR_SLOTS; i++) {
      const sl = document.createElement('div');
      sl.className = 'inv-slot' + (i === 0 ? ' selected' : '');
      sl.dataset.source = 'hud-hotbar';
      sl.dataset.index  = i;
      sl.innerHTML = `<span class="slot-key">${i + 1}</span>`;
      sl.addEventListener('click', () => this.selectHotbar(i));
      hudHb.appendChild(sl);
    }
  }

  _renderSlot(el, item) {
    const key = el.querySelector('.slot-key');
    const keyHTML = key ? key.outerHTML : '';
    if (!item) { el.innerHTML = keyHTML; return; }
    const def = ITEMS[item.id];
    const icon = def?.icon ?? '?';
    el.innerHTML = keyHTML +
      `<span>${icon}</span>` +
      (item.qty > 1 ? `<span class="slot-qty">${item.qty}</span>` : '');
  }

  render() {
    // Inventory grid
    const invSlots = document.querySelectorAll('#inv-grid .inv-slot');
    invSlots.forEach((el, i) => this._renderSlot(el, this.slots[i]));

    // Hotbar in inventory
    const hbSlots = document.querySelectorAll('#inv-hotbar .inv-slot');
    hbSlots.forEach((el, i) => this._renderSlot(el, this.hotbar[i]));

    // HUD hotbar
    const hudSlots = document.querySelectorAll('#hotbar .inv-slot');
    hudSlots.forEach((el, i) => {
      this._renderSlot(el, this.hotbar[i]);
      el.classList.toggle('selected', i === this.hotbarSelected);
    });

    // Equipment
    for (const [slot, item] of Object.entries(this.equip)) {
      const el = document.getElementById(`equip-${slot}`);
      if (el) this._renderSlot(el, item);
    }

    // Stats
    const weightEl = document.getElementById('inv-weight');
    const countEl  = document.getElementById('inv-count');
    if (weightEl) weightEl.textContent = this.getTotalWeight().toFixed(1);
    if (countEl)  countEl.textContent  = this.slots.filter(Boolean).length;
  }

  // ── Drag & Drop ───────────────────────────────────────────────────────────────
  _bindDragEvents() {
    document.addEventListener('mousedown', e => {
      const sl = e.target.closest('.inv-slot');
      if (!sl || !this._open) return;
      const src = sl.dataset.source;
      const idx = parseInt(sl.dataset.index);
      const item = src === 'inv' ? this.slots[idx]
                 : src === 'hotbar' || src === 'hud-hotbar' ? this.hotbar[idx]
                 : src.startsWith('equip') ? this.equip[src.replace('equip-', '')]
                 : null;
      if (!item) return;
      e.preventDefault();
      this._dragging = { source: src, index: idx, item: { ...item } };
      this._dragEl = document.createElement('div');
      this._dragEl.className = 'drag-ghost';
      this._dragEl.textContent = ITEMS[item.id]?.icon ?? '?';
      this._dragEl.style.cssText = `position:fixed;pointer-events:none;z-index:9999;font-size:1.5rem;`;
      document.body.appendChild(this._dragEl);
      this._moveDrag(e);
    });

    document.addEventListener('mousemove', e => {
      if (this._dragEl) this._moveDrag(e);
      // Tooltip
      const sl = e.target.closest('.inv-slot');
      if (sl) {
        const src = sl.dataset.source;
        const idx = parseInt(sl.dataset.index);
        const item = src === 'inv' ? this.slots[idx] : this.hotbar[idx];
        this._showTooltip(item, e);
      } else this._hideTooltip();
    });

    document.addEventListener('mouseup', e => {
      if (!this._dragging || !this._dragEl) return;
      const sl = e.target.closest('.inv-slot');
      if (sl) this._dropOnSlot(sl);
      if (this._dragEl) { this._dragEl.remove(); this._dragEl = null; }
      this._dragging = null;
      this.render();
    });
  }

  _moveDrag(e) {
    if (!this._dragEl) return;
    this._dragEl.style.left = (e.clientX - 14) + 'px';
    this._dragEl.style.top  = (e.clientY - 14) + 'px';
  }

  _dropOnSlot(targetEl) {
    const tSrc = targetEl.dataset.source;
    const tIdx = parseInt(targetEl.dataset.index);
    const drag = this._dragging;

    const getArr  = src => src === 'inv' ? this.slots : this.hotbar;
    const srcArr  = getArr(drag.source);
    const dstArr  = getArr(tSrc);

    if (!dstArr) return;
    const tmp      = dstArr[tIdx];
    dstArr[tIdx]   = srcArr[drag.index];
    srcArr[drag.index] = tmp;
  }

  _showTooltip(item, e) {
    const tip = document.getElementById('item-tooltip');
    if (!item) { tip.classList.add('hidden'); return; }
    const def = ITEMS[item.id];
    if (!def) { tip.classList.add('hidden'); return; }
    let html = `<div class="tooltip-name">${def.icon} ${def.name}</div>`;
    if (def.damage)        html += `<div class="tooltip-stats">⚔ Damage: ${def.damage}</div>`;
    if (def.hungerRestore) html += `<div class="tooltip-stats">🍖 Hunger: +${def.hungerRestore}</div>`;
    if (def.thirstRestore) html += `<div class="tooltip-stats">💧 Thirst: +${def.thirstRestore}</div>`;
    if (def.healthRestore) html += `<div class="tooltip-stats">❤ Health: +${def.healthRestore}</div>`;
    if (def.durability)    html += `<div class="tooltip-stats">Durability: ${def.durability}</div>`;
    html += `<div class="tooltip-desc">${def.cat}</div>`;
    tip.innerHTML = html;
    tip.classList.remove('hidden');
    tip.style.left = Math.min(e.clientX + 12, window.innerWidth  - 220) + 'px';
    tip.style.top  = Math.min(e.clientY + 12, window.innerHeight - 120) + 'px';
  }

  _hideTooltip() {
    document.getElementById('item-tooltip').classList.add('hidden');
  }

  // ── Item management ───────────────────────────────────────────────────────────
  addItem(id, qty) {
    const def = ITEMS[id];
    if (!def) return false;
    const max = def.max ?? CONFIG.MAX_STACK;

    // Try to stack in hotbar first
    for (let i = 0; i < this.hotbar.length; i++) {
      const s = this.hotbar[i];
      if (s && s.id === id && s.qty < max) {
        const add = Math.min(qty, max - s.qty);
        s.qty += add; qty -= add;
        if (qty === 0) { this.render(); return true; }
      }
    }

    // Then inventory
    for (let i = 0; i < this.slots.length; i++) {
      const s = this.slots[i];
      if (s && s.id === id && s.qty < max) {
        const add = Math.min(qty, max - s.qty);
        s.qty += add; qty -= add;
        if (qty === 0) { this.render(); return true; }
      }
    }

    // Empty slots
    while (qty > 0) {
      const all = [...this.hotbar, ...this.slots];
      let placed = false;
      for (let i = 0; i < this.hotbar.length; i++) {
        if (!this.hotbar[i]) { this.hotbar[i] = { id, qty: Math.min(qty, max) }; qty -= Math.min(qty, max); placed = true; break; }
      }
      if (!placed) {
        for (let i = 0; i < this.slots.length; i++) {
          if (!this.slots[i]) { this.slots[i] = { id, qty: Math.min(qty, max) }; qty -= Math.min(qty, max); placed = true; break; }
        }
      }
      if (!placed) { this.game.ui.notify('Inventory full!', 'warning'); break; }
      if (qty <= 0) break;
    }
    this.render();
    return true;
  }

  removeItem(id, qty) {
    let remaining = qty;
    const sources = [...this.hotbar, ...this.slots];
    for (const s of sources) {
      if (!s || s.id !== id) continue;
      const take = Math.min(s.qty, remaining);
      s.qty -= take; remaining -= take;
      if (remaining <= 0) break;
    }
    // Clean up empty stacks
    for (let i = 0; i < this.hotbar.length; i++) if (this.hotbar[i]?.qty <= 0) this.hotbar[i] = null;
    for (let i = 0; i < this.slots.length;  i++) if (this.slots[i]?.qty  <= 0) this.slots[i]  = null;
    this.render();
    return remaining === 0;
  }

  countItem(id) {
    let total = 0;
    [...this.hotbar, ...this.slots].forEach(s => { if (s && s.id === id) total += s.qty; });
    return total;
  }

  getHotbarItem(idx) { return this.hotbar[idx] ?? null; }

  consumeHotbarItem(idx, qty) {
    const s = this.hotbar[idx];
    if (!s) return;
    s.qty -= qty;
    if (s.qty <= 0) this.hotbar[idx] = null;
    this.render();
  }

  selectHotbar(idx) {
    this.hotbarSelected = idx;
    document.querySelectorAll('#hotbar .inv-slot').forEach((el, i) => {
      el.classList.toggle('selected', i === idx);
    });
  }

  getTotalWeight() {
    let w = 0;
    [...this.hotbar, ...this.slots].forEach(s => {
      if (s) w += (ITEMS[s.id]?.weight ?? 0) * s.qty;
    });
    return w;
  }

  dropHalf() {
    for (let i = 0; i < this.slots.length; i++) {
      if (this.slots[i]) { this.slots[i].qty = Math.ceil(this.slots[i].qty / 2); if (this.slots[i].qty <= 0) this.slots[i] = null; }
    }
    this.render();
  }

  reset() {
    this.slots  = Array(CONFIG.INV_ROWS * CONFIG.INV_COLS).fill(null);
    this.hotbar = Array(CONFIG.HOTBAR_SLOTS).fill(null);
    this.equip  = { weapon: null, head: null, chest: null, legs: null, feet: null };
    this.hotbarSelected = 0;
    this.render();
  }

  open() {
    this._open = true;
    document.getElementById('inventory-panel').classList.remove('hidden');
    this.render();
  }

  close() {
    this._open = false;
    document.getElementById('inventory-panel').classList.add('hidden');
    this._hideTooltip();
    if (this.game.state === 'playing') this.game.player.controls.lock();
  }

  isOpen() { return this._open; }

  loadState(data) {
    this.slots  = data.slots  ?? Array(CONFIG.INV_ROWS * CONFIG.INV_COLS).fill(null);
    this.hotbar = data.hotbar ?? Array(CONFIG.HOTBAR_SLOTS).fill(null);
    this.equip  = data.equip  ?? { weapon: null, head: null, chest: null, legs: null, feet: null };
    this.render();
  }

  getState() {
    return { slots: this.slots, hotbar: this.hotbar, equip: this.equip };
  }
}
