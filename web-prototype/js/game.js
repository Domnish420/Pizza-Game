/* Crust Empire – state, economy, helpers */
const SAVE_KEY = 'crust-empire-v1';
let G = null;

const $ = s => document.querySelector(s);
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
const rnd = (a, b) => a + Math.random() * (b - a);
const pick = a => a[Math.floor(Math.random() * a.length)];
const money = n => (n < 0 ? '-$' : '$') + Math.abs(Math.round(n)).toLocaleString('en-US');
const cents = n => '$' + n.toFixed(2);
const stars = n => '★'.repeat(n) + '☆'.repeat(5 - n);

function newGame() {
  const upg = {};
  for (const k in UPG) upg[k] = 0;
  return {
    day: 1, cash: 150, xp: 0, level: 1, rep: 3, ratings: 0, venue: 0, upg, tables: 0,
    stock: { flour: 3, yeast: 3, salt: 3, tomato: 8, mozz: 8, basil: 8 },
    dough: { n: 0, q: 0 }, menu: { margherita: true }, price: 1,
    staff: [], cands: [], last: null, sid: 1, mute: false, total: { pizzas: 0, earned: 0 },
  };
}
function save() { try { localStorage.setItem(SAVE_KEY, JSON.stringify(G)); } catch (e) {} }
function load() {
  try {
    const s = JSON.parse(localStorage.getItem(SAVE_KEY));
    if (s && s.upg) { const n = newGame(); G = Object.assign(n, s); G.upg = Object.assign(n.upg, s.upg); return true; }
  } catch (e) {}
  return false;
}

const xpNeed = l => Math.round(100 * Math.pow(l, 1.3) + 50);
function addXP(n) {
  G.xp += Math.round(n);
  let ups = 0;
  while (G.xp >= xpNeed(G.level)) { G.xp -= xpNeed(G.level); G.level++; ups++; }
  return ups;
}
function unlocksAt(l) {
  const out = [];
  RECIPES.forEach(r => { if (r.lvl === l) out.push('🍕 ' + r.name + ' recipe'); });
  VENUES.forEach(v => { if (v.lvl === l && v.cost) out.push(v.icon + ' ' + v.name + ' for sale'); });
  if (l === 2) out.push('👥 You can hire staff');
  return out;
}

const tier = id => UPG[id].tiers[G.upg[id]];
const staffOf = r => G.staff.filter(s => s.role === r);
const skillOf = r => staffOf(r).reduce((a, s) => a + s.skill, 0);
const stock = id => G.stock[id] || 0;

/* Everything the upgrades and staff add up to */
function calc() {
  const v = VENUES[G.venue], c = { v };
  const oven = tier('oven');
  c.slots = oven.slots; c.ovenQ = oven.q;
  c.fornaio = staffOf('fornaio').length > 0;
  c.bake = oven.bake * (c.fornaio ? 0.9 : 1);
  c.batch = tier('mixer').batch; c.knead = tier('mixer').knead;
  c.spoil = tier('fridge').spoil;
  c.manager = staffOf('manager').length > 0;
  c.prepSpeed = 1 + tier('prep').speed + staffOf('prep').length * 0.08 + (c.manager ? 0.1 : 0);
  c.prepQ = tier('prep').q; c.brush = tier('prep').brush;
  c.proofQ = tier('proofer').q; c.proofZone = tier('proofer').zone;
  c.turn = tier('dish').turn / (1 + 0.25 * staffOf('porter').length);
  c.costMult = tier('supplier').mult; c.supQ = tier('supplier').q;
  c.patience = 1 + tier('pos').pat + tier('comfort').pat + skillOf('cashier') * 0.05;
  c.queueCap = 5 + staffOf('cashier').length * 3 + G.upg.pos * 2 + staffOf('pizzaiolo').length * 2;
  c.repMult = 0.4 + G.rep * 0.22;
  const host = staffOf('host')[0];
  c.trafficMult = c.repMult * [1.2, 1, 0.82][G.price] *
    (1 + tier('sign').tr + tier('marketing').tr + tier('pos').tr + tier('comfort').tr + (host ? 0.06 + 0.02 * host.skill : 0));
  c.customers = Math.round(v.traffic * c.trafficMult);
  c.tablesOwned = Math.min(G.tables, v.tables);
  c.tables = Math.min(c.tablesOwned, 2 + staffOf('server').length * 4);
  let dt = G.upg.drinks;
  if (dt >= 3 && !staffOf('bartender').length) dt = 2;
  c.drinks = UPG.drinks.tiers[dt].per * (1 + skillOf('bartender') * 0.06);
  c.delivery = Math.round(staffOf('driver').length * tier('delivery').per * c.repMult);
  c.tip = 1 + tier('furniture').tip + tier('ambience').tip + skillOf('server') * 0.03;
  c.repBonus = tier('ambience').rep;
  c.priceMult = [0.85, 1, 1.2][G.price];
  c.total = c.customers + c.delivery;
  return c;
}

const activeRecipes = () => RECIPES.filter(r => G.menu[r.id] && G.level >= r.lvl);
const recipeIngs = r => [r.sauce, 'mozz', ...r.tops];
const canMake = r => G.dough.n >= 1 && recipeIngs(r).every(i => stock(i) >= 1);
const ingPrice = id => ING[id].price * calc().costMult;

function buy(id, n) {
  const cost = ingPrice(id) * n;
  if (G.cash < cost) return false;
  G.cash -= cost; G.stock[id] = stock(id) + n;
  return true;
}

/* What a day's trade needs, given the active menu */
function parStock() {
  const c = calc(), recs = activeRecipes(), need = {};
  const exp = Math.ceil(c.total * 1.15) + 1;
  if (!recs.length) return { need, exp };
  recs.forEach(r => recipeIngs(r).forEach(i => { need[i] = (need[i] || 0) + exp / recs.length; }));
  for (const k in need) need[k] = Math.ceil(need[k] + (recs.length > 1 ? 2 : 0));
  const batches = Math.max(0, Math.ceil((exp - G.dough.n) / 6));
  need.flour = need.yeast = need.salt = batches;
  return { need, exp };
}
function quickOrder() {
  const { need } = parStock();
  let spent = 0, short = false;
  for (const id in need) {
    const n = Math.max(0, need[id] - stock(id));
    if (!n) continue;
    const afford = Math.min(n, Math.floor(Math.max(0, G.cash) / ingPrice(id)));
    if (afford < n) short = true;
    if (afford > 0) { spent += ingPrice(id) * afford; buy(id, afford); }
  }
  return { spent, short };
}
function quickOrderCost() {
  const { need } = parStock();
  let t = 0;
  for (const id in need) t += Math.max(0, need[id] - stock(id)) * ingPrice(id);
  return t;
}

function addDough(n, q) {
  const d = G.dough;
  d.q = d.n + n ? (d.q * d.n + q * n) / (d.n + n) : 0;
  d.n += n;
}
/* Prep cooks make the morning dough */
function autoDough() {
  const cooks = staffOf('prep');
  if (!cooks.length) return 0;
  const c = calc(), want = Math.ceil(c.total * 1.15) + 1 - G.dough.n;
  const batches = Math.min(Math.ceil(want / 6), stock('flour'), stock('yeast'), stock('salt'));
  if (batches <= 0) return 0;
  ['flour', 'yeast', 'salt'].forEach(i => { G.stock[i] -= batches; });
  const sk = skillOf('prep') / cooks.length;
  addDough(batches * 6, clamp(52 + sk * 7 + c.proofQ, 0, 100));
  return batches * 6;
}

/* Upgrades */
function nextTier(id) { return UPG[id].tiers[G.upg[id] + 1] || null; }
function buyUpgrade(id) {
  const t = nextTier(id);
  if (!t || G.venue < t.v || G.cash < t.c) return false;
  G.cash -= t.c; G.upg[id]++;
  return true;
}
const tableCost = () => 120 + 40 * G.tables;

/* Staff */
function roleOpen(k) {
  const r = ROLES[k];
  return G.venue >= r.v && G.level >= (r.lvl || 1);
}
function genCands() {
  G.cands = [];
  for (const k in ROLES) {
    if (!roleOpen(k)) continue;
    for (let i = 0; i < 2; i++) {
      const skill = clamp(1 + Math.floor(Math.random() * (2.2 + G.venue * 0.6)), 1, 4);
      G.cands.push({ id: G.sid++, role: k, name: pick(NAMES), skill, wage: Math.round(ROLES[k].wage * (0.7 + 0.15 * skill) * rnd(0.92, 1.08)) });
    }
  }
}
const areaCount = a => G.staff.filter(s => ROLES[s.role].area === a).length;
function hireBlock(cd) {
  const r = ROLES[cd.role], v = VENUES[G.venue];
  if (areaCount(r.area) >= v[r.area]) return (r.area === 'boh' ? 'Kitchen' : 'Front of house') + ' is full here';
  if (r.max && staffOf(cd.role).length >= r.max) return 'You already have one';
  if (r.needs && !G.upg[r.needs]) return 'Buy a ' + UPG[r.needs].name + ' upgrade first';
  return '';
}
const trainCost = s => Math.round(120 * s.skill * ROLES[s.role].wage / 40);
const wages = () => G.staff.reduce((a, s) => a + s.wage, 0);

/* Sound */
const Sound = (() => {
  let ac = null;
  function tone(f, d, type, vol, when) {
    if (!G || G.mute) return;
    try {
      ac = ac || new (window.AudioContext || window.webkitAudioContext)();
      const o = ac.createOscillator(), g = ac.createGain(), t = ac.currentTime + (when || 0);
      o.type = type || 'sine'; o.frequency.value = f;
      g.gain.setValueAtTime(vol || 0.08, t); g.gain.exponentialRampToValueAtTime(0.001, t + d);
      o.connect(g); g.connect(ac.destination); o.start(t); o.stop(t + d);
    } catch (e) {}
  }
  return {
    ding: () => { tone(880, 0.25, 'sine', 0.07); tone(1320, 0.3, 'sine', 0.05, 0.08); },
    cash: () => { tone(1200, 0.08, 'square', 0.04); tone(1600, 0.2, 'square', 0.04, 0.07); },
    bad: () => tone(160, 0.3, 'sawtooth', 0.06),
    tap: () => tone(520, 0.05, 'triangle', 0.05),
    up: () => { [523, 659, 784, 1047].forEach((f, i) => tone(f, 0.25, 'triangle', 0.07, i * 0.09)); },
  };
})();
