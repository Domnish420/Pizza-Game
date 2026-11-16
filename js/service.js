/* Crust Empire – live service: tickets, the bench, the oven, the cutting board */
const Service = (() => {
  const W = 320, CX = 160, CY = 160, R = 108, NS = 24, CELL = 12, DAY = 180;
  const cells = [];
  for (let y = CELL / 2; y < W; y += CELL) for (let x = CELL / 2; x < W; x += CELL)
    if (Math.hypot(x - CX, y - CY) < R * 0.84) cells.push([x, y]);

  let S = null, cv, ctx, raf = 0, last = 0, ptr = null, pid = 1, dirty = true, uiClock = 0, popT = 0;

  /* ---------- pizza model ---------- */
  function newPizza(tk) {
    const mk = () => { const c = document.createElement('canvas'); c.width = c.height = W; return c; };
    return { id: pid++, tk, rec: tk.rec, r: Array(NS).fill(R * 0.46), doughQ: G.dough.q, stage: 'stretch',
      sauce: null, sauceCells: new Uint8Array(cells.length), cheese: false, cheeseCells: new Uint8Array(cells.length),
      tops: [], sauceCv: mk(), cheeseCv: mk(), bake: 0, cuts: [] };
  }
  const radAt = (pz, ang) => {
    const f = ((ang / (Math.PI * 2)) % 1 + 1) % 1 * NS, i = Math.floor(f), t = f - i;
    return pz.r[i % NS] * (1 - t) + pz.r[(i + 1) % NS] * t;
  };
  const cov = a => { let n = 0; for (let i = 0; i < a.length; i++) n += a[i]; return clamp(n / a.length / 0.85, 0, 1); };
  function stretchScore(pz) {
    let s = 0;
    for (const r of pz.r) s += clamp(1 - Math.max(0, Math.abs(r - R) / R - 0.04) * 2.8, 0, 1);
    return s / NS;
  }
  function topScore(pz, t) {
    const ps = pz.tops.filter(p => p.t === t);
    if (!ps.length) return 0;
    const q = new Set(ps.map(p => (p.x > CX ? 1 : 0) + (p.y > CY ? 2 : 0)));
    return Math.min(1, ps.length / 5) * (q.size / 4);
  }
  function bakeScore(p) {
    if (p < 0.6) return 0;
    if (p < 0.92) return 0.2 + (p - 0.6) / 0.32 * 0.7;
    if (p <= 1.12) return 1;
    if (p < 1.4) return 1 - (p - 1.12) / 0.28 * 0.7;
    return 0;
  }
  function cutScore(pz) {
    const best = pz.cuts.map(c => 0.5 + 0.5 * (1 - c.d / (R * 0.35))).sort((a, b) => b - a).slice(0, 3);
    return best.reduce((a, b) => a + b, 0) / 3;
  }
  function scorePizza(pz) {
    const rec = pz.rec, c = S.c;
    const p = { stretch: stretchScore(pz), sauce: pz.sauce === rec.sauce ? cov(pz.sauceCells) : 0, cheese: cov(pz.cheeseCells),
      tops: rec.tops.reduce((a, t) => a + topScore(pz, t), 0) / rec.tops.length, bake: bakeScore(pz.bake), cut: cutScore(pz) };
    let total = (p.stretch * 15 + p.sauce * 15 + p.cheese * 15 + p.tops * 20 + p.bake * 25 + p.cut * 10) * 0.85 + pz.doughQ * 0.15 + c.ovenQ * 0.5 + c.supQ;
    const extra = new Set(pz.tops.map(t => t.t).filter(t => !rec.tops.includes(t))).size;
    total -= extra * 10;
    if (pz.sauce && pz.sauce !== rec.sauce) total -= 15;
    if (pz.bake < 0.6 || pz.bake > 1.5) total = Math.min(total, 30);
    p.total = clamp(Math.round(total), 0, 100);
    p.note = pz.bake < 0.6 ? 'Raw in the middle!' : pz.bake > 1.4 ? 'Burnt!' : extra ? 'Wrong toppings' : (pz.sauce && pz.sauce !== rec.sauce) ? 'Wrong sauce' : '';
    return p;
  }

  /* ---------- simulation ---------- */
  function spawn() {
    const c = S.c;
    const avail = activeRecipes().filter(canMake);
    if (!avail.length) { S.r.sold++; G.rep += (2 - G.rep) * 0.01; return; }
    if (S.tickets.length >= c.queueCap) { S.r.walk++; return; }
    let type = 'take';
    if (c.delivery && Math.random() < c.delivery / c.total) type = 'deliv';
    else if (c.tablesOwned && Math.random() < 0.6) {
      if (S.tablesBusy < c.tables) { type = 'dine'; S.tablesBusy++; }
      else if (Math.random() < 0.5) { S.r.walk++; return; }
    }
    const max = { take: 85, dine: 100, deliv: 110 }[type] * c.patience * rnd(0.85, 1.15);
    S.tickets.push({ id: S.nid++, rec: pick(avail), type, pat: max, max, age: 0, owner: null });
    Sound.ding(); dirty = true;
  }
  function consume(rec) { G.dough.n--; recipeIngs(rec).forEach(i => { G.stock[i]--; }); }
  function staffQ(s) {
    const c = S.c, hc = staffOf('headchef')[0];
    return clamp(45 + s.skill * 8 + (hc ? 4 + hc.skill * 2 : 0) + c.ovenQ + c.prepQ + c.supQ + (G.dough.q - 60) * 0.15 + rnd(-5, 5), 20, 99);
  }
  function removeTicket(tk) {
    const i = S.tickets.indexOf(tk);
    if (i >= 0) S.tickets.splice(i, 1);
    tk.gone = true; dirty = true;
  }
  function expire(tk) {
    removeTicket(tk);
    S.r.lost++;
    G.rep += (1.5 - G.rep) * Math.max(0.02, 1 / (G.ratings + 6)) * 0.35;
    if (tk.type === 'dine') S.tablesBusy--;
    S.workers.forEach(w => { if (w.job === tk) w.job = null; });
    S.oven = S.oven.filter(o => !(o.owner === 'staff' && o.tk === tk));
    Sound.bad(); flash('#' + tk.id + ' gave up waiting', 'bad');
  }
  function finishTicket(tk, score, mine) {
    const c = S.c, r = S.r, price = tk.rec.price * c.priceMult;
    const adj = score + [4, 0, -6][G.price], pf = clamp(tk.pat / tk.max, 0, 1);
    let pay = adj < 30 ? 0 : price, tip = 0;
    if (pay) tip = price * Math.max(0, (adj - 55) / 45) * 0.22 * (0.5 + 0.5 * pf) * c.tip * (tk.type === 'dine' ? 1.5 : 1);
    const drinks = c.drinks * (tk.type === 'dine' ? 1 : 0.35) * rnd(0.6, 1.4);
    const deliv = tk.type === 'deliv' ? 2.5 : 0;
    const st = clamp(1 + adj / 25 + (tk.type === 'dine' ? c.repBonus : 0) - (pf < 0.15 ? 0.5 : 0), 1, 5);
    G.ratings++;
    G.rep = clamp(G.rep + (st - G.rep) * Math.max(0.02, 1 / (G.ratings + 4)), 1, 5);
    G.cash += pay + tip + drinks + deliv;
    r.food += pay; r.tips += tip; r.drinks += drinks; r.deliv += deliv; r.served++; r.qsum += score;
    if (mine) r.mine++;
    r.xp += mine ? 12 + score / 8 : 4;
    G.total.pizzas++; G.total.earned += pay + tip + drinks + deliv;
    removeTicket(tk);
    if (tk.type === 'dine') S.eating.push(22 * c.turn);
    return { pay, tip, st };
  }
  function step(dt) {
    const c = S.c;
    S.t += dt;
    if (S.t < DAY * 0.95) {
      S.acc += c.total / DAY * (0.55 + 0.9 * Math.sin(Math.PI * S.t / DAY)) / 1.123 / 0.95 * dt;
      while (S.acc >= 1) { S.acc -= 1; spawn(); }
    }
    for (const tk of S.tickets.slice()) { tk.age += dt; tk.pat -= dt; if (tk.pat <= 0) expire(tk); }
    for (let i = S.eating.length - 1; i >= 0; i--) if ((S.eating[i] -= dt) <= 0) { S.eating.splice(i, 1); S.tablesBusy--; }
    for (const w of S.workers) {
      if (w.job) {
        w.left -= dt;
        if (w.left <= 0 && S.oven.length < c.slots) { S.oven.push({ owner: 'staff', tk: w.job, q: staffQ(w.s), p: 0 }); w.job = null; dirty = true; }
      }
      if (!w.job) {
        const tk = S.tickets.find(t => !t.owner && t.age > 1.2 && canMake(t.rec));
        if (tk) { consume(tk.rec); tk.owner = w.s.name; w.job = tk; w.left = 12 * (1.25 - 0.1 * w.s.skill) / c.prepSpeed; dirty = true; }
      }
    }
    for (const o of S.oven.slice()) {
      o.p += dt / c.bake;
      if (o.owner === 'staff' && o.p >= 1) { S.oven.splice(S.oven.indexOf(o), 1); finishTicket(o.tk, o.q, false); dirty = true; }
      else if (o.owner === 'me' && c.fornaio && o.p >= 1.02) pull(o.pz.id);
    }
    const idle = !S.tickets.length && !S.bench && !S.board.length && !S.oven.length;
    if (idle && (S.t >= DAY || (G.dough.n < 1 && S.t > 3))) finish(G.dough.n < 1 && S.t < DAY * 0.9);
  }

  /* ---------- player actions ---------- */
  function claim(id) {
    const tk = S.tickets.find(t => t.id === +id);
    if (!tk || tk.owner) return;
    if (S.bench) return flash('Finish the pizza on your bench first', 'bad');
    if (G.dough.n < 1) return flash('No dough balls left!', 'bad');
    G.dough.n--; tk.owner = 'me';
    S.bench = newPizza(tk); S.view = 'bench'; S.tool = null; dirty = true; Sound.tap();
  }
  function next() {
    const pz = S.bench;
    if (S.view === 'board') return serve();
    if (!pz) return;
    if (pz.stage === 'stretch') {
      pz.stage = 'top';
      S.tool = stock(pz.rec.sauce) ? pz.rec.sauce : null;
    } else {
      if (S.oven.length >= S.c.slots) return flash('The oven is full', 'bad');
      S.oven.push({ owner: 'me', pz, p: 0 });
      S.bench = null; S.tool = null;
      if (S.board.length) S.view = 'board';
    }
    dirty = true; Sound.tap();
  }
  function bin() {
    if (S.view === 'board') { const pz = S.board.shift(); if (pz && !pz.tk.gone) pz.tk.owner = null; if (!S.board.length) S.view = 'bench'; }
    else if (S.bench) { if (!S.bench.tk.gone) S.bench.tk.owner = null; S.bench = null; S.tool = null; }
    dirty = true;
  }
  function pull(id) {
    const o = S.oven.find(o => o.owner === 'me' && o.pz.id === +id);
    if (!o) return;
    S.oven.splice(S.oven.indexOf(o), 1);
    o.pz.bake = o.p; o.pz.stage = 'board';
    S.board.push(o.pz);
    if (!S.bench) S.view = 'board';
    dirty = true; Sound.tap();
  }
  function serve() {
    const pz = S.board[0];
    if (!pz) return;
    if (pz.tk.gone) {
      const alt = S.tickets.find(t => !t.owner && t.rec === pz.rec);
      if (!alt) { S.board.shift(); if (!S.board.length) S.view = 'bench'; dirty = true; return flash('That customer left. Pizza binned', 'bad'); }
      alt.owner = 'me'; pz.tk = alt;
    }
    const p = scorePizza(pz), res = finishTicket(pz.tk, p.total, true);
    S.board.shift();
    if (!S.board.length) S.view = 'bench';
    const pc = v => Math.round(v * 100);
    $('#sv-pop').innerHTML = `<b>${res.st.toFixed(1)}★ ${pz.rec.name}</b><span>${p.note || (p.total >= 85 ? 'Bellissima!' : p.total >= 65 ? 'Nice pizza' : 'Needs work')}</span>
      <small>Stretch ${pc(p.stretch)} · Sauce ${pc(p.sauce)} · Cheese ${pc(p.cheese)}<br>Toppings ${pc(p.tops)} · Bake ${pc(p.bake)} · Cut ${pc(p.cut)}</small>
      <em>${res.pay ? '+' + cents(res.pay) : 'Refunded'}${res.tip > 0.05 ? ' · tip ' + cents(res.tip) : ''}</em>`;
    $('#sv-pop').hidden = false; popT = 3.2;
    res.pay ? Sound.cash() : Sound.bad();
    dirty = true;
  }
  function flash(msg, cls) { UI.toast(msg, cls); }

  /* ---------- canvas input ---------- */
  function pos(e) {
    const b = cv.getBoundingClientRect();
    if (document.body.classList.contains('rot')) return { x: (e.clientY - b.top) / b.height * W, y: (b.right - e.clientX) / b.width * W };
    return { x: (e.clientX - b.left) / b.width * W, y: (e.clientY - b.top) / b.height * W };
  }
  function mark(arr, x, y, rad) { for (let i = 0; i < cells.length; i++) if (!arr[i] && Math.hypot(cells[i][0] - x, cells[i][1] - y) < rad) arr[i] = 1; }
  function act(p, prev) {
    const pz = S.bench;
    if (S.view !== 'bench' || !pz) return;
    const d = Math.hypot(p.x - CX, p.y - CY), ang = Math.atan2(p.y - CY, p.x - CX);
    if (pz.stage === 'stretch') {
      if (!prev) return;
      const gain = d - Math.hypot(prev.x - CX, prev.y - CY);
      if (gain <= 0) return;
      for (let i = 0; i < NS; i++) {
        let da = Math.abs(ang - i / NS * Math.PI * 2) % (Math.PI * 2);
        if (da > Math.PI) da = Math.PI * 2 - da;
        if (d < pz.r[i] + 40) pz.r[i] = Math.min(pz.r[i] + gain * (Math.exp(-Math.pow(da / 0.6, 2)) * 0.8 + 0.12) * (pz.r[i] > R ? 0.2 : 1), R * 1.15);
      }
      return;
    }
    const t = S.tool;
    if (!t || d > radAt(pz, ang) * 0.92) return;
    const kind = ING[t].kind, brush = 17 + S.c.brush;
    if (kind === 'sauce') {
      if (!pz.sauce) { if (stock(t) < 1) return; G.stock[t]--; pz.sauce = t; dirty = true; }
      if (pz.sauce !== t) return;
      const g = pz.sauceCv.getContext('2d');
      g.fillStyle = ING[t].color; g.globalAlpha = 0.9;
      g.beginPath(); g.arc(p.x, p.y, brush, 0, 7); g.fill();
      mark(pz.sauceCells, p.x, p.y, brush + 3); dirty = true;
    } else if (kind === 'cheese') {
      if (!pz.cheese) { if (stock(t) < 1) return; G.stock[t]--; pz.cheese = true; }
      const g = pz.cheeseCv.getContext('2d');
      for (let i = 0; i < 7; i++) {
        const a = rnd(0, 7), rr = rnd(0, brush), x = p.x + Math.cos(a) * rr, y = p.y + Math.sin(a) * rr;
        g.save(); g.translate(x, y); g.rotate(rnd(0, 3.2));
        g.fillStyle = pick(['#fff6d6', '#fdeeb5', '#fbe7a0']); g.fillRect(-6, -2, 12, 4); g.restore();
      }
      mark(pz.cheeseCells, p.x, p.y, brush + 2); dirty = true;
    } else {
      const same = pz.tops.filter(q => q.t === t);
      if (same.length >= 14 || same.some(q => Math.hypot(q.x - p.x, q.y - p.y) < 20)) return;
      if (!same.length) { if (stock(t) < 1) return; G.stock[t]--; }
      pz.tops.push({ t, x: p.x, y: p.y, a: rnd(0, 6.3) }); dirty = true;
    }
  }
  function down(e) {
    e.preventDefault();
    try { cv.setPointerCapture(e.pointerId); } catch (x) {}
    ptr = pos(e); ptr.sx = ptr.x; ptr.sy = ptr.y;
    act(ptr, null);
  }
  function move(e) {
    if (!ptr) return;
    const p = pos(e); act(p, ptr);
    ptr.x = p.x; ptr.y = p.y;
  }
  function up() {
    if (!ptr) return;
    const pz = S.board[0];
    if (S.view === 'board' && pz) {
      const x1 = ptr.sx, y1 = ptr.sy, x2 = ptr.x, y2 = ptr.y, len = Math.hypot(x2 - x1, y2 - y1);
      if (len > R * 1.2) {
        const d = Math.abs((y2 - y1) * CX - (x2 - x1) * CY + x2 * y1 - y2 * x1) / len;
        if (d < R * 0.35 && pz.cuts.length < 4) { pz.cuts.push({ x1, y1, x2, y2, d }); Sound.tap(); dirty = true; }
        else if (d >= R * 0.35) flash('Cut through the middle', 'bad');
      }
    }
    ptr = null;
  }

  /* ---------- drawing ---------- */
  function doughPath(g, pz, k) {
    const pts = [];
    for (let i = 0; i < NS; i++) { const a = i / NS * Math.PI * 2; pts.push([CX + Math.cos(a) * pz.r[i] * k, CY + Math.sin(a) * pz.r[i] * k]); }
    g.beginPath();
    for (let i = 0; i < NS; i++) {
      const a = pts[i], b = pts[(i + 1) % NS], mx = (a[0] + b[0]) / 2, my = (a[1] + b[1]) / 2;
      if (!i) g.moveTo((pts[NS - 1][0] + a[0]) / 2, (pts[NS - 1][1] + a[1]) / 2);
      g.quadraticCurveTo(a[0], a[1], mx, my);
    }
    g.closePath();
  }
  function drawTop(g, t) {
    switch (t) {
      case 'basil': g.fillStyle = '#3f9142'; g.beginPath(); g.ellipse(0, 0, 10, 5.5, 0, 0, 7); g.fill(); g.strokeStyle = '#2b6b2f'; g.lineWidth = 1; g.beginPath(); g.moveTo(-9, 0); g.lineTo(9, 0); g.stroke(); break;
      case 'pepperoni': g.fillStyle = '#a92a1e'; g.beginPath(); g.arc(0, 0, 9, 0, 7); g.fill(); g.fillStyle = '#7d1b12'; [[-3, -2], [3, 2], [1, -4], [-2, 4]].forEach(p => { g.beginPath(); g.arc(p[0], p[1], 1.4, 0, 7); g.fill(); }); break;
      case 'mushroom': g.fillStyle = '#e2d3b5'; g.strokeStyle = '#8c7658'; g.lineWidth = 1.2; g.beginPath(); g.arc(0, 0, 8, Math.PI, 0); g.closePath(); g.fill(); g.stroke(); g.fillRect(-2.5, 0, 5, 6); g.strokeRect(-2.5, 0, 5, 6); break;
      case 'pepper': g.strokeStyle = '#3d9a3a'; g.lineWidth = 3.5; g.lineCap = 'round'; g.beginPath(); g.arc(0, 0, 7.5, 0.4, 4.2); g.stroke(); break;
      case 'onion': g.strokeStyle = '#a9549f'; g.lineWidth = 2; g.beginPath(); g.arc(0, 0, 8, 0, 7); g.stroke(); g.strokeStyle = '#e3bfe0'; g.lineWidth = 1.5; g.beginPath(); g.arc(0, 0, 5, 0, 7); g.stroke(); break;
      case 'olive': g.fillStyle = '#1e1b1b'; g.beginPath(); g.arc(0, 0, 6, 0, 7); g.fill(); g.fillStyle = '#b9442b'; g.beginPath(); g.arc(0, 0, 2.2, 0, 7); g.fill(); break;
      case 'ham': g.fillStyle = '#ee9aa2'; g.fillRect(-7, -5.5, 14, 11); g.strokeStyle = '#d6707b'; g.lineWidth = 1; g.strokeRect(-7, -5.5, 14, 11); break;
      case 'pineapple': g.fillStyle = '#f4cf3d'; g.beginPath(); g.moveTo(0, -7); g.lineTo(8, 6); g.lineTo(-8, 6); g.closePath(); g.fill(); g.strokeStyle = '#c89d1c'; g.lineWidth = 1; g.stroke(); break;
      case 'sausage': g.fillStyle = '#7b4a2c'; g.beginPath(); g.arc(-2, 0, 5.5, 0, 7); g.arc(3, 1, 5, 0, 7); g.fill(); g.fillStyle = '#9a6240'; g.beginPath(); g.arc(-2, -1, 2, 0, 7); g.fill(); break;
      case 'chicken': g.fillStyle = '#ecd2a0'; g.fillRect(-7, -5, 14, 10); g.strokeStyle = '#a8763a'; g.lineWidth = 1.5; g.beginPath(); g.moveTo(-5, -3); g.lineTo(5, 3); g.stroke(); break;
      case 'prosciutto': g.fillStyle = '#d8656f'; g.beginPath(); g.ellipse(0, 0, 13, 6, 0, 0, 7); g.fill(); g.strokeStyle = '#f6d6d6'; g.lineWidth = 2; g.beginPath(); g.moveTo(-9, -1); g.quadraticCurveTo(0, 4, 9, -1); g.stroke(); break;
      case 'rocket': g.strokeStyle = '#2f7d32'; g.lineWidth = 2.5; g.lineCap = 'round'; g.beginPath(); g.moveTo(-10, 0); g.quadraticCurveTo(0, -6, 10, 2); g.moveTo(-2, -2); g.lineTo(-5, -7); g.moveTo(3, -1); g.lineTo(6, 6); g.stroke(); break;
    }
  }
  function drawPizza(pz, baked) {
    const g = ctx, p = baked ? pz.bake : 0;
    g.save();
    g.shadowColor = 'rgba(0,0,0,.35)'; g.shadowBlur = 10; g.shadowOffsetY = 4;
    doughPath(g, pz, 1); g.fillStyle = '#f1dfb6'; g.fill();
    g.restore();
    g.strokeStyle = '#d9c08c'; g.lineWidth = 5; doughPath(g, pz, 0.97); g.stroke();
    g.save(); doughPath(g, pz, 0.9); g.clip();
    g.drawImage(pz.sauceCv, 0, 0); g.drawImage(pz.cheeseCv, 0, 0);
    g.restore();
    for (const t of pz.tops) { g.save(); g.translate(t.x, t.y); g.rotate(t.a); drawTop(g, t.t); g.restore(); }
    if (p > 0) {
      doughPath(g, pz, 1);
      g.fillStyle = `rgba(160,90,20,${0.28 * Math.min(p, 1.1)})`; g.fill();
      if (p > 1.12) { g.fillStyle = `rgba(25,12,5,${clamp((p - 1.12) / 0.5, 0, 0.85)})`; g.fill(); }
    }
    g.strokeStyle = 'rgba(255,250,235,.95)'; g.lineWidth = 2.5; g.lineCap = 'round';
    for (const c of pz.cuts) { g.beginPath(); g.moveTo(c.x1, c.y1); g.lineTo(c.x2, c.y2); g.stroke(); }
  }
  function draw() {
    const g = ctx, board = S.view === 'board';
    g.clearRect(0, 0, W, W);
    g.fillStyle = board ? '#6b4a2b' : '#8a8f8a'; g.fillRect(0, 0, W, W);
    if (board) { g.fillStyle = '#c69a62'; g.beginPath(); g.arc(CX, CY, R * 1.3, 0, 7); g.fill(); g.strokeStyle = '#a57c48'; g.lineWidth = 3; g.stroke(); }
    else { g.fillStyle = 'rgba(255,255,255,.07)'; for (let i = 0; i < 40; i++) g.fillRect((i * 97) % W, (i * 53) % W, 3, 3); }
    const pz = board ? S.board[0] : S.bench;
    g.textAlign = 'center'; g.font = '600 15px Nunito, system-ui, sans-serif';
    if (!pz) {
      g.fillStyle = 'rgba(20,30,24,.75)';
      g.fillText(G.dough.n < 1 ? 'Out of dough balls' : 'Tap a ticket to start a pizza', CX, CY - 6);
      g.font = '13px Nunito, system-ui, sans-serif';
      g.fillText(G.dough.n + ' dough ball' + (G.dough.n === 1 ? '' : 's') + ' left', CX, CY + 16);
      return;
    }
    if (pz.stage === 'stretch') {
      g.setLineDash([6, 6]); g.strokeStyle = 'rgba(255,255,255,.85)'; g.lineWidth = 2;
      g.beginPath(); g.arc(CX, CY, R, 0, 7); g.stroke(); g.setLineDash([]);
    }
    drawPizza(pz, board);
    if (board && ptr) { g.strokeStyle = 'rgba(255,255,255,.6)'; g.lineWidth = 2; g.setLineDash([4, 4]); g.beginPath(); g.moveTo(ptr.sx, ptr.sy); g.lineTo(ptr.x, ptr.y); g.stroke(); g.setLineDash([]); }
  }

  /* ---------- DOM ---------- */
  function sync(box, items, key, make, upd) {
    const have = new Map();
    [...box.children].forEach(el => have.set(el.dataset.k, el));
    items.forEach(it => {
      const k = String(key(it));
      let el = have.get(k);
      if (!el) { el = make(it); el.dataset.k = k; box.appendChild(el); } else have.delete(k);
      upd(el, it);
    });
    have.forEach(el => el.remove());
  }
  const TYPE = { take: '🥡', dine: '🍽️', deliv: '🛵' };
  function renderUI() {
    const c = S.c, pz = S.view === 'board' ? S.board[0] : S.bench;
    $('#sv-clock').style.width = clamp(S.t / DAY * 100, 0, 100) + '%';
    $('#sv-time').textContent = S.t >= DAY ? 'Last orders' : ['Lunch', 'Afternoon', 'Dinner rush', 'Late'][Math.min(3, Math.floor(S.t / DAY * 4))];
    $('#sv-cash').textContent = money(G.cash);
    $('#sv-rep').textContent = G.rep.toFixed(1) + '★';
    $('#sv-dough').textContent = '🫓 ' + G.dough.n;
    $('#sv-count').textContent = `Served ${S.r.served} · Lost ${S.r.lost + S.r.walk}`;
    sync($('#tickets'), S.tickets.slice(0, 12), t => t.id, t => {
      const el = document.createElement('button');
      el.className = 'tk'; el.dataset.a = 'claim'; el.dataset.id = t.id;
      el.innerHTML = `<span class="tk-h"><b>#${t.id} ${t.rec.name}</b><span>${TYPE[t.type]}</span></span>
        <span class="tk-ing">${recipeIngs(t.rec).map(i => ING[i].icon).join(' ')}</span><span class="tk-own"></span><span class="tk-bar"><i></i></span>`;
      return el;
    }, (el, t) => {
      const f = t.pat / t.max;
      el.querySelector('i').style.width = f * 100 + '%';
      el.querySelector('i').className = f < 0.25 ? 'low' : f < 0.5 ? 'mid' : '';
      el.classList.toggle('mine', t.owner === 'me'); el.classList.toggle('staff', !!t.owner && t.owner !== 'me');
      el.querySelector('.tk-own').textContent = t.owner === 'me' ? 'You' : t.owner ? '👨‍🍳 ' + t.owner : 'Tap to make';
    });
    $('#tk-more').textContent = S.tickets.length > 12 ? `+${S.tickets.length - 12} more waiting` : S.tickets.length ? '' : 'No orders yet…';
    const mine = S.oven.filter(o => o.owner === 'me');
    sync($('#oven-slots'), mine, o => o.pz.id, o => {
      const el = document.createElement('button');
      el.className = 'slot'; el.dataset.a = 'pull'; el.dataset.id = o.pz.id;
      el.innerHTML = `<span>${o.pz.rec.name}</span><span class="slot-bar"><u></u><i></i></span><em></em>`;
      return el;
    }, (el, o) => {
      el.querySelector('i').style.width = clamp(o.p / 1.6 * 100, 0, 100) + '%';
      const st = o.p < 0.92 ? 'Baking…' : o.p <= 1.12 ? 'PERFECT – pull!' : o.p < 1.4 ? 'Overdone!' : 'Burning!';
      el.querySelector('em').textContent = st;
      el.className = 'slot ' + (o.p < 0.92 ? '' : o.p <= 1.12 ? 'ok' : 'burn');
    });
    $('#oven-head').textContent = `Oven ${S.oven.length}/${c.slots}` + (S.oven.length - mine.length ? ` · ${S.oven.length - mine.length} staff` : '');
    if (!dirty) return;
    dirty = false;
    $('#tab-bench').classList.toggle('on', S.view === 'bench');
    $('#tab-board').classList.toggle('on', S.view === 'board');
    $('#tab-board').textContent = `Cutting board (${S.board.length})`;
    const nb = $('#sv-next'), bb = $('#sv-bin');
    nb.hidden = bb.hidden = !pz;
    if (pz) nb.textContent = S.view === 'board' ? 'Serve 🛎️' : pz.stage === 'stretch' ? 'Dough ready ▶' : 'Into the oven 🔥';
    // checklist + palette
    let h = '';
    if (!pz) h = '<p class="hint">Tap an order on the left, stretch the dough, top it, bake it, slice it, serve it.</p>';
    else if (S.view === 'board') h = `<p class="hint"><b>#${pz.tk.id} ${pz.rec.name}</b><br>Swipe across the pizza to slice it. 3 cuts through the middle, then serve.</p><p class="hint">Cuts: ${pz.cuts.length}/3</p>`;
    else if (pz.stage === 'stretch') h = `<p class="hint"><b>#${pz.tk.id} ${pz.rec.name}</b><br>Drag from the middle outward, all the way round, until the dough fills the dotted ring.</p><p class="hint">Evenness ${Math.round(stretchScore(pz) * 100)}%</p>`;
    else {
      const rec = pz.rec, pc = v => Math.round(v * 100) + '%';
      const row = (id, v) => `<li class="${v >= 0.8 ? 'done' : ''}">${ING[id].icon} ${ING[id].name}<b>${pc(v)}</b></li>`;
      h = `<ul class="check"><li class="head">#${pz.tk.id} ${rec.name}</li>${row(rec.sauce, pz.sauce === rec.sauce ? cov(pz.sauceCells) : 0)}${row('mozz', cov(pz.cheeseCells))}${rec.tops.map(t => row(t, topScore(pz, t))).join('')}</ul><div class="pal">`;
      const used = new Set(); activeRecipes().forEach(r => recipeIngs(r).forEach(i => used.add(i)));
      [...used].forEach(id => {
        const need = recipeIngs(rec).includes(id), on = pz.sauce === id || (id === 'mozz' && pz.cheese) || pz.tops.some(t => t.t === id);
        h += `<button class="pb ${S.tool === id ? 'sel' : ''} ${need ? 'need' : ''}" data-a="tool" data-id="${id}" ${stock(id) < 1 && !on ? 'disabled' : ''}>${ING[id].icon}<small>${stock(id)}</small></button>`;
      });
      h += '</div>';
    }
    $('#sv-side').innerHTML = h;
  }
  function fit() {
    if (!cv) return;
    const box = cv.parentElement, s = Math.floor(Math.min(box.clientWidth, box.clientHeight));
    cv.style.width = cv.style.height = s + 'px';
  }
  function loop(now) {
    if (!S) return;
    const real = Math.min(0.1, (now - last) / 1000 || 0); last = now;
    for (let i = 0; S && i < S.speed; i++) step(real);
    if (!S) return;
    if (popT > 0 && (popT -= real) <= 0) $('#sv-pop').hidden = true;
    draw();
    uiClock += real;
    if (uiClock > 0.1 || dirty) { uiClock = 0; renderUI(); }
    raf = requestAnimationFrame(loop);
  }

  function start() {
    const c = calc();
    S = { c, t: 0, acc: 0.75, speed: 1, tickets: [], nid: 1, bench: null, oven: [], board: [], tool: null, view: 'bench',
      workers: staffOf('pizzaiolo').map(s => ({ s, job: null, left: 0 })), tablesBusy: 0, eating: [],
      r: { day: G.day, served: 0, mine: 0, lost: 0, walk: 0, sold: 0, food: 0, tips: 0, drinks: 0, deliv: 0, qsum: 0, xp: 0, rep0: G.rep, lvl0: G.level } };
    $('#service').innerHTML = `
      <div class="sv-top">
        <span class="sv-time"><b id="sv-time"></b><span class="clock"><i id="sv-clock"></i></span></span>
        <span id="sv-count"></span><span id="sv-dough"></span><span id="sv-rep"></span><b id="sv-cash"></b>
        <button class="btn sm" data-a="speed" id="sv-speed">1×</button>
        <button class="btn sm ghost" data-a="closeEarly" id="sv-close">Close up</button>
      </div>
      <div class="sv-body">
        <div class="sv-left"><h4>Orders</h4><div id="tickets"></div><p id="tk-more" class="hint"></p></div>
        <div class="sv-mid">
          <div class="tabs"><button id="tab-bench" data-a="view" data-id="bench">Bench</button><button id="tab-board" data-a="view" data-id="board">Cutting board</button></div>
          <div class="cv-box"><canvas id="cv"></canvas><div id="sv-pop" hidden></div></div>
          <div class="sv-btns"><button class="btn ghost" id="sv-bin" data-a="bin">🗑 Bin</button><button class="btn" id="sv-next" data-a="next"></button></div>
        </div>
        <div class="sv-right"><div id="sv-side"></div><div class="oven"><h4 id="oven-head">Oven</h4><div id="oven-slots"></div></div></div>
      </div>`;
    UI.screen('service');
    cv = $('#cv'); const dpr = Math.min(2, window.devicePixelRatio || 1);
    cv.width = cv.height = W * dpr; ctx = cv.getContext('2d'); ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    cv.addEventListener('pointerdown', down); cv.addEventListener('pointermove', move);
    cv.addEventListener('pointerup', up); cv.addEventListener('pointercancel', up);
    fit(); dirty = true; last = performance.now(); closeArmed = 0;
    raf = requestAnimationFrame(loop);
  }

  function finish(soldOut) {
    cancelAnimationFrame(raf);
    const r = S.r, v = S.c.v, sp = S.c.spoil;
    S = null;
    r.soldOut = !!soldOut;
    r.rent = v.rent; r.rentName = v.rentName; r.wages = wages();
    r.interest = G.cash < 0 ? -G.cash * 0.05 : 0;
    G.cash -= r.rent + r.wages + r.interest;
    r.spoiled = 0;
    const rot = n => clamp(Math.round(n * sp + rnd(-0.5, 0.5)), 0, n);
    for (const id in G.stock) if (ING[id].perish) { const l = rot(G.stock[id]); G.stock[id] -= l; r.spoiled += l; }
    r.doughLost = rot(G.dough.n); G.dough.n -= r.doughLost;
    r.xp = Math.round(r.xp + 20);
    r.ups = addXP(r.xp); r.level = G.level; r.rep1 = G.rep;
    r.profit = r.food + r.tips + r.drinks + r.deliv - r.rent - r.wages - r.interest;
    G.day++; genCands(); G.last = r; save();
    UI.screen('hub'); UI.summary(r);
  }

  let closeArmed = 0;
  Object.assign(ACT, {
    claim: d => S && claim(d.id), next: () => S && next(), bin: () => S && bin(), pull: d => S && pull(d.id),
    tool: d => { if (S) { S.tool = d.id; dirty = true; Sound.tap(); } },
    view: d => { if (S) { S.view = d.id; dirty = true; } },
    speed: () => { if (!S) return; const max = S.workers.length ? 8 : 4; S.speed = S.speed >= max ? 1 : S.speed * 2; $('#sv-speed').textContent = S.speed + '×'; },
    closeEarly: () => {
      if (!S) return;
      if (Date.now() - closeArmed < 3000) return finish(false);
      closeArmed = Date.now(); $('#sv-close').textContent = 'Tap again to close';
      setTimeout(() => { const b = $('#sv-close'); if (b) b.textContent = 'Close up'; }, 3000);
    },
  });
  window.addEventListener('crust-layout', fit);
  return { start, active: () => !!S, _s: () => S };
})();
