'use strict';

class CraftingSystem {
  constructor(game, recipes) {
    this.game    = game;
    this.recipes = recipes || [];
    this._open   = false;
    this._selected = null;
    this._qty    = 1;
    this._currentCat = 'all';

    this._bindEvents();
  }

  _bindEvents() {
    document.getElementById('btn-close-craft').addEventListener('click', () => this.close());

    document.querySelectorAll('.cat-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        this._currentCat = btn.dataset.cat;
        document.querySelectorAll('.cat-btn').forEach(b => b.classList.toggle('active', b === btn));
        this._renderList();
      });
    });

    document.getElementById('craft-qty-dec').addEventListener('click', () => {
      if (this._qty > 1) { this._qty--; this._updateDetail(); }
    });
    document.getElementById('craft-qty-inc').addEventListener('click', () => {
      this._qty++;
      this._updateDetail();
    });
  }

  open() {
    this._open = true;
    document.getElementById('crafting-panel').classList.remove('hidden');
    this._renderList();
  }

  close() {
    this._open = false;
    document.getElementById('crafting-panel').classList.add('hidden');
    if (this.game.state === 'playing') this.game.player.controls.lock();
  }

  isOpen() { return this._open; }

  _renderList() {
    const list = document.getElementById('craft-list');
    list.innerHTML = '';

    const cat = this._currentCat;
    const filtered = cat === 'all' ? this.recipes : this.recipes.filter(r => r.category === cat);

    filtered.forEach(recipe => {
      const canCraft = this._canCraft(recipe, 1);
      const el = document.createElement('div');
      el.className = `craft-item${canCraft ? '' : ' unavailable'}${this._selected === recipe ? ' selected' : ''}`;
      el.innerHTML = `
        <span class="craft-item-icon">${recipe.icon}</span>
        <div class="craft-item-info">
          <div class="craft-item-name">${recipe.name}</div>
          <div class="craft-item-cat">${recipe.category}</div>
        </div>`;
      el.addEventListener('click', () => {
        this._selected = recipe;
        this._qty = 1;
        document.querySelectorAll('.craft-item').forEach(e => e.classList.remove('selected'));
        el.classList.add('selected');
        this._updateDetail();
      });
      list.appendChild(el);
    });
  }

  _canCraft(recipe, qty) {
    for (const [id, needed] of Object.entries(recipe.ingredients)) {
      if (this.game.inventory.countItem(id) < needed * qty) return false;
    }
    // Check workbench requirement
    if (recipe.requiresWorkbench) {
      const hasWorkbench = this.game.building.hasPlaced('workbench') ||
                           this.game.inventory.countItem('workbench') > 0;
      if (!hasWorkbench) return false;
    }
    return true;
  }

  _maxCraftable(recipe) {
    let max = Infinity;
    for (const [id, needed] of Object.entries(recipe.ingredients)) {
      if (needed > 0) max = Math.min(max, Math.floor(this.game.inventory.countItem(id) / needed));
    }
    return max === Infinity ? 0 : max;
  }

  _updateDetail() {
    const recipe = this._selected;
    const btn    = document.getElementById('btn-craft');
    const qtyEl  = document.getElementById('craft-qty');
    const ingEl  = document.getElementById('craft-ingredients');
    const nameEl = document.getElementById('craft-detail-name');
    const iconEl = document.getElementById('craft-detail-icon');
    const descEl = document.getElementById('craft-detail-desc');

    if (!recipe) {
      btn.disabled = true;
      nameEl.textContent = 'Select a recipe';
      iconEl.textContent = '🔧';
      descEl.textContent = '';
      ingEl.innerHTML = '';
      return;
    }

    const maxQ   = this._maxCraftable(recipe);
    this._qty    = Math.max(1, Math.min(this._qty, Math.max(1, maxQ)));
    const canNow = this._canCraft(recipe, this._qty);

    iconEl.textContent = recipe.icon;
    nameEl.textContent = recipe.name;
    descEl.textContent = recipe.desc || '';
    qtyEl.textContent  = this._qty;
    btn.disabled = !canNow;

    ingEl.innerHTML = '';
    for (const [id, needed] of Object.entries(recipe.ingredients)) {
      const have = this.game.inventory.countItem(id);
      const total = needed * this._qty;
      const ok    = have >= total;
      const def   = ITEMS[id];
      const row   = document.createElement('div');
      row.className = `ingredient-row ${ok ? 'has' : 'lacks'}`;
      row.innerHTML = `<span class="ingredient-icon">${def?.icon ?? '?'}</span>
                       <span>${def?.name ?? id}: ${have} / ${total}</span>
                       <span>${ok ? '✓' : '✗'}</span>`;
      ingEl.appendChild(row);
    }

    if (recipe.requiresWorkbench) {
      const hw  = this.game.building.hasPlaced('workbench') || this.game.inventory.countItem('workbench') > 0;
      const row = document.createElement('div');
      row.className = `ingredient-row ${hw ? 'has' : 'lacks'}`;
      row.innerHTML = `<span class="ingredient-icon">🔧</span><span>Workbench required</span><span>${hw ? '✓' : '✗'}</span>`;
      ingEl.appendChild(row);
    }
  }

  craftSelected() {
    const recipe = this._selected;
    if (!recipe) return;
    if (!this._canCraft(recipe, this._qty)) return;

    // Consume ingredients
    for (const [id, needed] of Object.entries(recipe.ingredients)) {
      this.game.inventory.removeItem(id, needed * this._qty);
    }

    // Add results
    const totalQty = recipe.result.qty * this._qty;
    this.game.inventory.addItem(recipe.result.id, totalQty);

    this.game.audio.playCraft();
    this.game.ui.notify(`Crafted ${totalQty}x ${recipe.name}!`, 'success');
    this.game.player.addXP(CONFIG.XP_CRAFT);

    this._qty = 1;
    this._renderList();
    this._updateDetail();
  }
}
