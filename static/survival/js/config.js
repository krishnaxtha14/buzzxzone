'use strict';

const CONFIG = {
  CHUNK_SIZE:           16,
  RENDER_DISTANCE:       3,
  TERRAIN_SCALE:       0.045,
  HEIGHT_SCALE:         22,
  SEA_LEVEL:             0,
  SEED:     Math.floor(Math.random() * 99999),

  PLAYER_HEIGHT:       1.8,
  PLAYER_RADIUS:       0.4,
  MOVE_SPEED:          5.5,
  SPRINT_SPEED:         10,
  CROUCH_SPEED:         2.5,
  JUMP_FORCE:            9,
  GRAVITY:             -22,
  MOUSE_SENSITIVITY:  0.002,

  MAX_HEALTH:          100,
  MAX_HUNGER:          100,
  MAX_THIRST:          100,
  MAX_STAMINA:         100,
  HUNGER_DRAIN:        0.28,
  THIRST_DRAIN:        0.45,
  STAMINA_DRAIN:        20,
  STAMINA_REGEN:        15,
  HUNGER_DAMAGE:       1.2,
  THIRST_DAMAGE:       2.0,
  HEALTH_REGEN:        0.5,

  XP_PER_LEVEL:        100,
  XP_GATHER:             5,
  XP_KILL:              25,
  XP_CRAFT:             10,
  XP_BUILD:              8,

  GATHER_RANGE:        3.5,
  GATHER_TIME_TREE:      3,
  GATHER_TIME_ROCK:      4,
  TREE_RESPAWN:         90,
  ROCK_RESPAWN:        150,

  MELEE_RANGE:         2.5,
  CRIT_CHANCE:        0.15,
  CRIT_MULT:           2.0,
  ATTACK_COOLDOWN:     0.6,

  DAY_DURATION:        480,
  NIGHT_DURATION:      240,

  WEATHER_INTERVAL:    180,

  INV_ROWS:              5,
  INV_COLS:              6,
  HOTBAR_SLOTS:          9,
  MAX_STACK:            64,

  BUILD_GRID:            2,

  WOLF_AGGRO:           12,
  ZOMBIE_AGGRO:         15,
  ENEMY_ATTACK_RANGE:    2,
  ENEMY_ATTACK_CD:      1.5,
  MAX_ENEMIES:          18,

  AUTOSAVE_INTERVAL:   300,
};

// ── Item Database ──────────────────────────────────────────────────────────────
const ITEMS = {
  wood:           { id:'wood',           name:'Wood',           icon:'🪵', max:64, weight:0.5, cat:'resource' },
  stone:          { id:'stone',          name:'Stone',          icon:'🪨', max:64, weight:1.0, cat:'resource' },
  iron:           { id:'iron',           name:'Iron Ore',       icon:'⚙',  max:32, weight:2.0, cat:'resource' },
  coal:           { id:'coal',           name:'Coal',           icon:'◼',  max:64, weight:1.0, cat:'resource' },
  stick:          { id:'stick',          name:'Stick',          icon:'🥢', max:64, weight:0.1, cat:'material' },
  rope:           { id:'rope',           name:'Rope',           icon:'🪢', max:16, weight:0.2, cat:'material' },
  raw_meat:       { id:'raw_meat',       name:'Raw Meat',       icon:'🥩', max:16, weight:0.5, cat:'food',    use:'eat',   hungerRestore:10, healthEffect:-5 },
  cooked_meat:    { id:'cooked_meat',    name:'Cooked Meat',    icon:'🍖', max:16, weight:0.5, cat:'food',    use:'eat',   hungerRestore:40 },
  berries:        { id:'berries',        name:'Berries',        icon:'🫐', max:32, weight:0.1, cat:'food',    use:'eat',   hungerRestore:15, thirstRestore:5 },
  water_flask:    { id:'water_flask',    name:'Water Flask',    icon:'🫙', max:4,  weight:0.5, cat:'survival',use:'drink', thirstRestore:50 },
  bandage:        { id:'bandage',        name:'Bandage',        icon:'🩹', max:10, weight:0.2, cat:'medical', use:'heal',  healthRestore:30 },
  torch:          { id:'torch',          name:'Torch',          icon:'🔦', max:8,  weight:0.3, cat:'survival',placeable:true },
  campfire:       { id:'campfire',       name:'Campfire',       icon:'🔥', max:1,  weight:3.0, cat:'building',placeable:true },
  workbench:      { id:'workbench',      name:'Workbench',      icon:'🔧', max:1,  weight:5.0, cat:'building',placeable:true },
  wooden_axe:     { id:'wooden_axe',     name:'Wooden Axe',     icon:'🪓', max:1,  weight:1.5, cat:'tool',    damage:15, gatherType:'tree', durability:50 },
  stone_axe:      { id:'stone_axe',      name:'Stone Axe',      icon:'⛏',  max:1,  weight:2.0, cat:'tool',    damage:20, gatherType:'tree', durability:100 },
  iron_axe:       { id:'iron_axe',       name:'Iron Axe',       icon:'🔨', max:1,  weight:2.5, cat:'tool',    damage:30, gatherType:'tree', durability:200 },
  wooden_pickaxe: { id:'wooden_pickaxe', name:'Wooden Pickaxe', icon:'⛏',  max:1,  weight:1.5, cat:'tool',    damage:10, gatherType:'rock', durability:40 },
  stone_pickaxe:  { id:'stone_pickaxe',  name:'Stone Pickaxe',  icon:'🪨', max:1,  weight:2.0, cat:'tool',    damage:20, gatherType:'rock', durability:80 },
  iron_pickaxe:   { id:'iron_pickaxe',   name:'Iron Pickaxe',   icon:'⚒',  max:1,  weight:2.5, cat:'tool',    damage:30, gatherType:'rock', durability:160 },
  spear:          { id:'spear',          name:'Spear',          icon:'🗡',  max:1,  weight:2.0, cat:'weapon',  damage:20, durability:60 },
  sword:          { id:'sword',          name:'Iron Sword',     icon:'⚔',  max:1,  weight:3.0, cat:'weapon',  damage:40, durability:150 },
  bow:            { id:'bow',            name:'Bow',            icon:'🏹', max:1,  weight:1.5, cat:'weapon',  damage:25, range:30, durability:100 },
  arrow:          { id:'arrow',          name:'Arrow',          icon:'➡',  max:64, weight:0.1, cat:'ammo' },
  wooden_wall:    { id:'wooden_wall',    name:'Wooden Wall',    icon:'🧱', max:10, weight:2.0, cat:'building',placeable:true },
  wooden_floor:   { id:'wooden_floor',   name:'Wooden Floor',   icon:'🟫', max:10, weight:2.0, cat:'building',placeable:true },
  wooden_door:    { id:'wooden_door',    name:'Wooden Door',    icon:'🚪', max:4,  weight:3.0, cat:'building',placeable:true },
  storage_chest:  { id:'storage_chest',  name:'Storage Chest',  icon:'📦', max:1,  weight:5.0, cat:'building',placeable:true },
};

// Build cost lookup for building panel
const BUILD_COSTS = {
  wooden_floor:  { wood: 2 },
  wooden_wall:   { wood: 3 },
  wooden_door:   { wood: 4 },
  campfire:      { wood: 5, stone: 3 },
  workbench:     { wood: 8 },
  storage_chest: { wood: 6 },
  torch:         { stick: 1, coal: 1 },
};
