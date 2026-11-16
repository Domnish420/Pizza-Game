/* Crust Empire – hub screens, dough making, day summary */
const ACT = {};

const UI = (() => {
  let tab = 'home', toastT = 0, armed = null;

  function screen(id) {
    $('#hub').hidden = id !== 'hub'; $('#service').hidden = id !== 'service';
    if (id === 'hub') render();
  }
  function toast(msg, cls) {
    const t = $('#toast');
    t.textContent = msg; t.className = cls || ''; t.hidden = false;
    clearTimeout(toastT); toastT = setTimeout(() => { t.hidden = true; }, 2200);
  }
  function modal(html) { $('#modal').innerHTML = `<div class="sheet">${html}</div>`; $('#modal').hidden = false; }
  function closeModal() { $('#modal').hidden = true; $('#modal').innerHTML = ''; }

  const TABS = [['home', '🏠', 'Today'], ['market', '🛒', 'Market'], ['dough', '🥣', 'Dough'], ['menu', '📋', 'Menu'],
    ['boh', '🔥', 'Kitchen'], ['foh', '🪑', 'Front'], ['staff', '👥', 'Staff'], ['property', '🏢', 'Property']];

  function render() {
    if (!G) return;
    const v = VENUES[G.venue], need = xpNeed(G.level);
    $('#top').innerHTML = `
      <span class="venue">${v.icon} <b>${v.name}</b></span>
      <span class="chip">Day ${G.day}</span>
      <span class="chip">${G.rep.toFixed(1)}★</span>
      <span class="chip lvl">Lv ${G.level}<span class="xp"><i style="width:${G.xp / need * 100}%"></i></span></span>
      <span class="cash ${G.cash < 0 ? 'neg' : ''}">${money(G.cash)}</span>
      <button class="btn sm ghost" data-a="mute" aria-label="Sound">${G.mute ? '🔇' : '🔊'}</button>
      <button class="btn sm ghost" data-a="full" aria-label="Full screen">⛶</button>
      <button class="btn open" data-a="open">Open up ▶</button>`;
    $('#rail').innerHTML = TABS.map(t => `<button class="${tab === t[0] ? 'on' : ''}" data-a="tab" data-id="${t[0]}"><span>${t[1]}</span>${t[2]}</button>`).join('');
    const pane = $('#pane'), sc = pane.scrollTop;
    pane.innerHTML = VIEW[tab]();
    pane.scrollTop = sc;
  }

  const upgCard = id => {
    const u = UPG[id], cur = tier(id), nx = nextTier(id);
    let foot = '<span class="tag ok">Top of the range</span>';
    if (nx) {
      const lock = G.venue < nx.v;
      foot = `<div class="nx"><b>Next: ${nx.n}</b><small>${nx.d}</small></div>` + (lock
        ? `<span class="tag">Needs ${VENUES[nx.v].name}</span>`
        : `<button class="btn sm" data-a="upg" data-id="${id}" ${G.cash < nx.c ? 'disabled' : ''}>Buy ${money(nx.c)}</button>`);
    }
    return `<div class="card"><h4>${u.icon} ${u.name} <span class="pips">${u.tiers.map((_, i) => `<i class="${i <= G.upg[id] ? 'on' : ''}"></i>`).join('')}</span></h4>
      <p><b>${cur.n}</b><small>${cur.d}</small></p>${foot}</div>`;
  };

  const VIEW = {
    home() {
      const c = calc(), v = c.v, recs = activeRecipes(), nv = VENUES[G.venue + 1], l = G.last;
      const missing = [...new Set(recs.flatMap(recipeIngs))].filter(i => stock(i) < 1).map(i => ING[i].name);
      const todo = [];
      if (G.dough.n < 1) todo.push(['bad', 'No dough balls. Make a batch in <b>Dough</b>.']);
      else if (G.dough.n < c.total * 0.7) todo.push(['warn', `${G.dough.n} dough balls for about ${c.total} customers. You may sell out early.`]);
      else todo.push(['ok', `${G.dough.n} dough balls ready (quality ${Math.round(G.dough.q)}).`]);
      if (missing.length) todo.push(['bad', `Out of ${missing.join(', ')}. Visit the <b>Market</b>.`]);
      else todo.push(['ok', 'Every menu item has ingredients in stock.']);
      if (G.cash < 0) todo.push(['bad', 'Overdrawn: the bank charges 5% a day.']);
      if (c.tablesOwned > c.tables) todo.push(['warn', `Only ${c.tables} of ${c.tablesOwned} tables can be served. Hire servers.`]);
      if (G.upg.drinks >= 3 && !staffOf('bartender').length) todo.push(['warn', 'The bar needs a bartender.']);
      if (G.upg.delivery && !staffOf('driver').length) todo.push(['warn', 'Delivery needs a driver.']);
      return `<div class="grid two">
        <div class="card hero"><div class="big">${v.icon}</div><div><h3>${v.name}</h3><p><small>${v.desc}</small></p>
          <div class="stats"><span>👥 ~${c.total} customers today</span><span>🔥 ${tier('oven').n}</span>
          <span>🧑‍🍳 ${G.staff.length} staff · ${money(wages())}/day</span><span>🏷️ ${v.rentName} ${money(v.rent)}/day</span>${c.tablesOwned ? `<span>🍽️ ${c.tables} tables in service</span>` : ''}</div></div></div>
        <div class="card"><h4>Before you open</h4><ul class="todo">${todo.map(t => `<li class="${t[0]}">${t[1]}</li>`).join('')}</ul>
          ${G.day === 1 ? '<p class="hint">First day: make dough, check your stock, then hit <b>Open up</b>. During service you stretch, top, bake and slice every pizza yourself.</p>' : ''}</div>
        ${l ? `<div class="card"><h4>Day ${l.day} takings</h4><div class="stats"><span>🍕 ${l.served} served</span><span>😤 ${l.lost + l.walk} lost</span>
          <span>Avg quality ${l.served ? Math.round(l.qsum / l.served) : 0}</span><span class="${l.profit < 0 ? 'neg' : 'pos'}">Profit ${money(l.profit)}</span></div></div>` : ''}
        <div class="card"><h4>Next step up</h4>${nv ? `<p><b>${nv.icon} ${nv.name}</b><small>${money(nv.cost)} · needs level ${nv.lvl}</small></p>
          <div class="bar"><i style="width:${clamp(G.cash / nv.cost * 100, 0, 100)}%"></i></div>` : '<p>You run the best pizzeria in town. Keep the ovens hot.</p>'}
          <p class="hint">${G.total.pizzas} pizzas sold · ${money(G.total.earned)} earned all-time <button class="link" data-a="reset">${armed === 'reset' ? 'Tap again to wipe your save' : 'Start over'}</button></p></div>
      </div>`;
    },
    market() {
      const used = new Set(activeRecipes().flatMap(recipeIngs)), qc = quickOrderCost(), { exp } = parStock();
      const rows = Object.keys(ING).filter(id => G.level >= ING[id].lvl).map(id => {
        const i = ING[id], p = ingPrice(id), on = used.has(id) || i.kind === 'dough';
        return `<div class="card ing ${on ? '' : 'dim'}"><h4>${i.icon} ${i.name}</h4><p><small>${cents(p)} each${i.perish ? ' · fresh' : ''}</small><b class="${on && stock(id) < 1 ? 'neg' : ''}">Have ${stock(id)}</b></p>
          <div class="buy">${[1, 5, 20].map(n => `<button class="btn sm" data-a="buy" data-id="${id}" data-n="${n}" ${G.cash < p * n ? 'disabled' : ''}>+${n}</button>`).join('')}</div></div>`;
      }).join('');
      return `<div class="strip"><span>One portion tops one pizza. Flour, yeast and salt: one of each makes 6 dough balls. Fresh stock spoils overnight (${Math.round(calc().spoil * 100)}% with your ${tier('fridge').n.toLowerCase()}).</span>
        <button class="btn sm" data-a="quick" ${qc <= 0 ? 'disabled' : ''}>${qc > 0 ? `Stock up for ~${exp} pizzas · ${cents(qc)}` : 'Fully stocked'}</button></div><div class="grid three">${rows}</div>`;
    },
    dough() {
      const c = calc(), can = Math.min(c.batch, stock('flour'), stock('yeast'), stock('salt'));
      return `<div class="grid two"><div class="card"><h4>🫓 Dough balls</h4><div class="big num">${G.dough.n}</div>
        <p><small>Average quality ${Math.round(G.dough.q)} / 100. Better dough lifts every pizza's score.</small></p>
        <p><small>You expect about ${c.total} customers today.</small></p></div>
        <div class="card"><h4>🥣 Make a batch</h4><p><b>${tier('mixer').n}</b><small>Up to ${c.batch * 6} balls per batch. Uses 1 flour, 1 yeast and 1 salt per 6 balls.</small></p>
        <p><small>In stock: 🌾 ${stock('flour')} · 🧫 ${stock('yeast')} · 🧂 ${stock('salt')}</small></p>
        <button class="btn" data-a="doughStart" ${can < 1 ? 'disabled' : ''}>${can < 1 ? 'Buy flour, yeast and salt first' : `Make ${can * 6} dough balls`}</button>
        ${staffOf('prep').length ? '<p class="hint">Your prep cook makes the morning dough automatically when you open.</p>' : ''}</div></div>`;
    },
    menu() {
      const pl = ['Budget', 'Standard', 'Premium'], pd = ['15% cheaper · more customers · forgiving', 'Fair prices', '20% dearer · fewer customers · fussier'];
      return `<div class="strip"><span><b>Pricing:</b> ${pd[G.price]}</span><span class="seg">${pl.map((p, i) => `<button class="${G.price === i ? 'on' : ''}" data-a="price" data-id="${i}">${p}</button>`).join('')}</span></div>
      <div class="grid three">${RECIPES.map(r => {
        const open = G.level >= r.lvl, on = G.menu[r.id];
        return `<div class="card ${open ? '' : 'dim'}"><h4>🍕 ${r.name}</h4><p><small>${recipeIngs(r).map(i => ING[i].icon + ' ' + ING[i].name).join(', ')}</small><b>${cents(r.price * calc().priceMult)}</b></p>
          ${open ? `<button class="btn sm ${on ? '' : 'ghost'}" data-a="menu" data-id="${r.id}">${on ? 'On the menu ✓' : 'Add to menu'}</button>` : `<span class="tag">Unlocks at level ${r.lvl}</span>`}</div>`;
      }).join('')}</div>`;
    },
    boh() { return `<div class="grid three">${Object.keys(UPG).filter(k => UPG[k].area === 'boh').map(upgCard).join('')}</div>`; },
    foh() {
      const v = VENUES[G.venue], c = calc();
      const tables = v.tables ? `<div class="card"><h4>🍽️ Tables <span class="tag">${c.tablesOwned}/${v.tables}</span></h4><p><b>${c.tables} in service</b><small>Dine-in guests tip more and buy drinks. Each server covers 4 tables; you can manage 2 from the counter.</small></p>
        ${c.tablesOwned < v.tables ? `<button class="btn sm" data-a="table" ${G.cash < tableCost() ? 'disabled' : ''}>Add a table ${money(tableCost())}</button>` : '<span class="tag ok">Room is full</span>'}</div>`
        : `<div class="card dim"><h4>🍽️ Tables</h4><p><small>No room for seating here. The Takeaway Shop has window seats.</small></p></div>`;
      return `<div class="grid three">${tables}${Object.keys(UPG).filter(k => UPG[k].area === 'foh').map(upgCard).join('')}</div>`;
    },
    staff() {
      const v = VENUES[G.venue];
      if (G.level < 2) return `<div class="card"><h4>👥 Just you for now</h4><p><small>Reach level 2 and you can take on a pizzaiolo or a counter assistant, even in the van.</small></p></div>`;
      const row = (s, hired) => {
        const r = ROLES[s.role], blk = hired ? '' : hireBlock(s);
        return `<div class="card person"><h4>${r.icon} ${s.name} <span class="tag">${r.name}</span></h4><p><span class="stars">${stars(s.skill)}</span><b>${money(s.wage)}/day</b></p><p><small>${r.desc}</small></p>
          <div class="buy">${hired
            ? `${s.skill < 5 ? `<button class="btn sm" data-a="train" data-id="${s.id}" ${G.cash < trainCost(s) ? 'disabled' : ''}>Train ${money(trainCost(s))}</button>` : '<span class="tag ok">Master</span>'}
               <button class="btn sm ghost" data-a="fire" data-id="${s.id}">${armed === 'fire' + s.id ? 'Sure?' : 'Let go'}</button>`
            : blk ? `<span class="tag">${blk}</span>` : `<button class="btn sm" data-a="hire" data-id="${s.id}">Hire</button>`}</div></div>`;
      };
      return `<div class="strip"><span>Kitchen <b>${areaCount('boh')}/${v.boh}</b> · Front of house <b>${areaCount('foh')}/${v.foh}</b> · Wages <b>${money(wages())}/day</b></span></div>
        ${G.staff.length ? `<h5>Your team</h5><div class="grid three">${G.staff.map(s => row(s, true)).join('')}</div>` : ''}
        <h5>Applicants today</h5><div class="grid three">${G.cands.map(s => row(s, false)).join('') || '<p class="hint">Nobody applied today.</p>'}</div>`;
    },
    property() {
      return `<div class="grid two">${VENUES.map((v, i) => {
        const st = i < G.venue ? '<span class="tag">Outgrown</span>' : i === G.venue ? '<span class="tag ok">You are here</span>'
          : i > G.venue + 1 ? `<span class="tag">Level ${v.lvl} · ${money(v.cost)}</span>`
          : G.level < v.lvl ? `<span class="tag">Needs level ${v.lvl} · ${money(v.cost)}</span>`
          : `<button class="btn sm" data-a="move" data-id="${i}" ${G.cash < v.cost ? 'disabled' : ''}>${armed === 'move' ? 'Confirm: sign the lease' : 'Buy & move in ' + money(v.cost)}</button>`;
        return `<div class="card ${i < G.venue ? 'dim' : ''}"><h4>${v.icon} ${v.name}</h4><p><small>${v.desc}</small></p>
          <div class="stats"><span>👥 ${v.traffic} base footfall</span><span>🏷️ ${money(v.rent)}/day</span><span>🔥 ${v.boh} kitchen staff</span><span>🤵 ${v.foh} front staff</span>${v.tables ? `<span>🍽️ ${v.tables} tables</span>` : ''}</div>${st}</div>`;
      }).join('')}</div><p class="hint">Your equipment, staff and reputation move with you.</p>`;
    },
  };

  function summary(r) {
    const line = (a, b, cls) => `<tr class="${cls || ''}"><td>${a}</td><td>${b}</td></tr>`;
    const ups = [];
    for (let l = r.lvl0 + 1; l <= r.level; l++) ups.push(...unlocksAt(l));
    if (r.ups) Sound.up();
    modal(`<h3>Day ${r.day} closed${r.soldOut ? ' – sold out!' : ''}</h3><div class="sum">
      <table>${line('Pizzas served', `${r.served} (${r.mine} by you)`)}${line('Customers lost', r.lost + r.walk + r.sold)}
        ${line('Average quality', r.served ? Math.round(r.qsum / r.served) : '–')}${line('Reputation', `${r.rep0.toFixed(2)} → ${r.rep1.toFixed(2)}★`)}
        ${line('Spoiled overnight', `${r.spoiled} portions${r.doughLost ? `, ${r.doughLost} dough` : ''}`)}${line('XP earned', '+' + r.xp)}</table>
      <table>${line('Pizza sales', money(r.food))}${r.drinks ? line('Drinks', money(r.drinks)) : ''}${r.deliv ? line('Delivery fees', money(r.deliv)) : ''}${line('Tips', money(r.tips))}
        ${line(r.rentName, money(-r.rent))}${r.wages ? line('Wages', money(-r.wages)) : ''}${r.interest ? line('Overdraft interest', money(-r.interest)) : ''}
        ${line('Profit', money(r.profit), r.profit < 0 ? 'tot neg' : 'tot pos')}</table></div>
      ${r.ups ? `<p class="lvlup">Level ${r.level}! ${ups.length ? 'Unlocked: ' + ups.join(' · ') : ''}</p>` : ''}
      ${r.walk > 3 ? '<p class="hint">Customers walked away from a long queue: more hands or a bigger oven would help.</p>' : ''}
      <button class="btn" data-a="closeModal">Next morning ▶</button>`);
  }

  /* arm-then-confirm for destructive taps (no native dialogs) */
  function arm(key) {
    if (armed === key) { armed = null; return true; }
    armed = key; render();
    setTimeout(() => { if (armed === key) { armed = null; if (!$('#hub').hidden) render(); } }, 3000);
    return false;
  }

  Object.assign(ACT, {
    tab: d => { tab = d.id; $('#pane').scrollTop = 0; render(); },
    mute: () => { G.mute = !G.mute; save(); render(); },
    full: () => {
      const el = document.documentElement;
      try {
        if (document.fullscreenElement) document.exitFullscreen();
        else el.requestFullscreen().then(() => screen.orientation && screen.orientation.lock && screen.orientation.lock('landscape').catch(() => {})).catch(() => toast('Full screen is not available here'));
      } catch (e) { toast('Full screen is not available here'); }
    },
    buy: d => { if (buy(d.id, +d.n)) { Sound.tap(); save(); render(); } },
    quick: () => { const r = quickOrder(); toast(r.short ? 'Bought what you could afford' : 'Stocked up: ' + cents(r.spent)); save(); render(); },
    price: d => { G.price = +d.id; save(); render(); },
    menu: d => {
      if (G.menu[d.id] && activeRecipes().length < 2) return toast('Keep at least one pizza on the menu', 'bad');
      G.menu[d.id] = !G.menu[d.id]; save(); render();
    },
    upg: d => { if (buyUpgrade(d.id)) { Sound.cash(); toast('Installed: ' + tier(d.id).n); save(); render(); } },
    table: () => { if (G.cash >= tableCost()) { G.cash -= tableCost(); G.tables++; Sound.cash(); save(); render(); } },
    hire: d => {
      const i = G.cands.findIndex(c => c.id === +d.id);
      if (i < 0 || hireBlock(G.cands[i])) return;
      const s = G.cands.splice(i, 1)[0]; G.staff.push(s);
      toast(s.name + ' joins the team'); Sound.up(); save(); render();
    },
    fire: d => { if (arm('fire' + d.id)) { G.staff = G.staff.filter(s => s.id !== +d.id); save(); render(); } },
    train: d => {
      const s = G.staff.find(s => s.id === +d.id), c = s && trainCost(s);
      if (!s || s.skill >= 5 || G.cash < c) return;
      G.cash -= c; s.skill++; s.wage = Math.round(s.wage * 1.12);
      toast(`${s.name} is now ${s.skill}★`); Sound.up(); save(); render();
    },
    move: d => {
      const v = VENUES[+d.id];
      if (+d.id !== G.venue + 1 || G.level < v.lvl || G.cash < v.cost) return;
      if (!arm('move')) return;
      G.cash -= v.cost; G.venue = +d.id; genCands(); Sound.up(); save(); tab = 'home'; render();
      modal(`<h3>${v.icon} Welcome to the ${v.name}</h3><p>${v.desc}</p><p class="hint">New equipment, staff roles and upgrades are now available. Check Kitchen, Front and Staff.</p><button class="btn" data-a="closeModal">Let's cook</button>`);
    },
    reset: () => { if (arm('reset')) { G = newGame(); genCands(); save(); tab = 'home'; render(); } },
    closeModal: () => { closeModal(); render(); },
    open: () => {
      let msg = [];
      if (calc().manager) { const r = quickOrder(); if (r.spent) msg.push('Manager ordered ' + cents(r.spent) + ' of stock'); }
      const made = autoDough(); if (made) msg.push('Prep cook made ' + made + ' dough balls');
      if (G.dough.n < 1) { tab = 'dough'; render(); return toast('No dough! Make a batch first', 'bad'); }
      if (!activeRecipes().some(canMake)) { tab = 'market'; render(); return toast('You are missing ingredients for every pizza', 'bad'); }
      if (msg.length) toast(msg.join(' · '));
      save(); Service.start();
    },
    doughStart: () => Dough.start(),
  });

  return { screen, render, toast, modal, closeModal, summary };
})();

/* ---------- Dough making: measure, knead, proof ---------- */
const Dough = (() => {
  let D = null, raf = 0, last = 0;
  const ZONE = [62, 74];

  function start() {
    const c = calc(), mult = Math.min(c.batch, stock('flour'), stock('yeast'), stock('salt'));
    if (mult < 1) return;
    ['flour', 'yeast', 'salt'].forEach(i => { G.stock[i] -= mult; });
    D = { c, mult, step: 0, flour: 0, water: 0, lock: {}, hold: null, knead: 0, proof: 0, scores: [], px: null };
    save(); view();
    last = performance.now(); raf = requestAnimationFrame(tick);
  }
  const barScore = v => clamp(100 - Math.max(0, Math.abs(v - 68) - 3) * 7, 0, 100);

  function view() {
    const m = D.mult * 6;
    let h = `<h3>Making ${m} dough balls <small>${['1 · Measure', '2 · Knead', '3 · Proof'][D.step] || ''}</small></h3>`;
    if (D.step === 0) {
      const bar = (k, label, ic) => `<div class="pour"><span>${ic} ${label}</span><div class="meter"><u style="left:${ZONE[0]}%;width:${ZONE[1] - ZONE[0]}%"></u><i id="m-${k}"></i></div>
        <button class="btn hold" id="b-${k}" data-hold="${k}" ${D.lock[k] ? 'disabled' : ''}>${D.lock[k] ? 'Done' : 'Hold to pour'}</button></div>`;
      h += `<p class="hint">Hold each button and let go when the bar is inside the marked zone. Too little or too much throws the hydration off.</p>
        ${bar('flour', 'Flour', '🌾')}${bar('water', 'Water', '💧')}
        <p class="hint">Yeast and a pinch of salt go in too.</p>`;
    } else if (D.step === 1) {
      h += `<p class="hint">Rub back and forth across the dough to knead. Stop in the marked zone: smooth and springy, not overworked.</p>
        <div class="meter"><u style="left:${85 / 1.2}%;width:${20 / 1.2}%"></u><i id="m-knead"></i></div>
        <div id="knead"><div id="blob"></div></div>
        <button class="btn" data-a="doughNext">Dough feels right ▶</button>`;
    } else if (D.step === 2) {
      const z = 8 + D.c.proofZone;
      h += `<p class="hint">The dough is rising. Ball it up when it has doubled, inside the marked zone. Too early is dense, too late collapses.</p>
        <div class="meter"><u style="left:${(100 - z) / 1.3}%;width:${2 * z / 1.3}%"></u><i id="m-proof"></i></div>
        <div class="rise"><div id="rise"></div></div>
        <button class="btn" data-a="doughNext">Ball it up!</button>`;
    } else {
      const q = D.q;
      h = `<h3>${m} dough balls ready</h3><div class="big num">${q}</div><p>Dough quality ${q >= 85 ? '– beautiful, airy dough.' : q >= 65 ? '– good honest dough.' : '– a bit rough. Watch the zones next time.'}</p>
        <p class="hint">Measure ${Math.round((D.scores[0] + D.scores[1]) / 2)} · Knead ${Math.round(D.scores[2])} · Proof ${Math.round(D.scores[3])}${D.c.proofQ ? ' · Proofing kit +' + D.c.proofQ : ''}</p>
        <button class="btn" data-a="closeModal">Done</button>`;
    }
    UI.modal(h);
    if (D && D.step === 1) {
      const k = $('#knead');
      k.addEventListener('pointerdown', e => { e.preventDefault(); D.px = [e.clientX, e.clientY]; });
      k.addEventListener('pointermove', e => {
        if (!D || !D.px) return;
        const d = Math.hypot(e.clientX - D.px[0], e.clientY - D.px[1]);
        D.knead = Math.min(120, D.knead + d * D.c.knead / 26);
        const b = $('#blob');
        if (b) b.style.transform = `translate(${clamp((e.clientX - D.px[0]) * 2, -30, 30)}px,0) scale(${1 + Math.sin(D.knead / 4) * 0.08},${1 - Math.sin(D.knead / 4) * 0.08})`;
        D.px = [e.clientX, e.clientY];
      });
      const end = () => { if (D) D.px = null; };
      k.addEventListener('pointerup', end); k.addEventListener('pointercancel', end); k.addEventListener('pointerleave', end);
    }
  }
  function tick(now) {
    if (!D) return;
    const dt = Math.min(0.1, (now - last) / 1000); last = now;
    if (D.step === 0) {
      if (D.hold && !D.lock[D.hold]) D[D.hold] = Math.min(100, D[D.hold] + dt * 42);
      ['flour', 'water'].forEach(k => { const el = $('#m-' + k); if (el) el.style.width = D[k] + '%'; });
    } else if (D.step === 1) {
      const el = $('#m-knead'); if (el) el.style.width = D.knead / 1.2 + '%';
    } else if (D.step === 2) {
      D.proof += dt * 15;
      const el = $('#m-proof'); if (el) el.style.width = Math.min(100, D.proof / 1.3) + '%';
      const r = $('#rise'); if (r) r.style.transform = `scale(${0.5 + Math.min(D.proof, 130) / 200})`;
      if (D.proof >= 130) next();
    }
    if (D && D.step < 3) raf = requestAnimationFrame(tick);
  }
  function release() {
    if (!D || D.step !== 0 || !D.hold) return;
    const k = D.hold; D.hold = null;
    if (D[k] < 4) return;
    D.lock[k] = true; D.scores[k === 'flour' ? 0 : 1] = barScore(D[k]);
    if (D.lock.flour && D.lock.water) { D.step = 1; Sound.tap(); }
    view();
  }
  function next() {
    if (!D) return;
    if (D.step === 1) {
      const k = D.knead;
      D.scores[2] = k < 85 ? k / 85 * 100 : k <= 105 ? 100 : Math.max(0, 100 - (k - 105) * 5);
      D.step = 2;
    } else if (D.step === 2) {
      const z = 8 + D.c.proofZone;
      D.scores[3] = D.proof >= 130 ? 30 : clamp(100 - Math.max(0, Math.abs(D.proof - 100) - z) * 4, 0, 100);
      D.q = clamp(Math.round(D.scores.reduce((a, b) => a + b, 0) / 4 + D.c.proofQ), 0, 100);
      addDough(D.mult * 6, D.q); D.step = 3; Sound.up(); save();
      view(); D = null; return;
    }
    view();
  }
  document.addEventListener('pointerdown', e => {
    const b = e.target.closest && e.target.closest('[data-hold]');
    if (b && D && !b.disabled) { e.preventDefault(); D.hold = b.dataset.hold; }
  });
  document.addEventListener('pointerup', release);
  document.addEventListener('pointercancel', release);
  ACT.doughNext = next;
  return { start, active: () => !!D };
})();

/* ---------- boot ---------- */
function boot() {
  if (!load()) { G = newGame(); genCands(); }
  if (!G.cands.length) genCands();
  document.addEventListener('click', e => {
    const el = e.target.closest('[data-a]');
    if (!el || el.disabled) return;
    const f = ACT[el.dataset.a];
    if (f) f(el.dataset, el);
  });
  document.addEventListener('contextmenu', e => e.preventDefault());
  /* Always landscape: if the screen is held upright (or rotation is locked), turn the whole game a quarter-turn. */
  const layout = () => {
    const w = window.innerWidth, h = window.innerHeight, rot = h > w, app = $('#app');
    document.body.classList.toggle('rot', rot);
    document.documentElement.style.fontSize = clamp(Math.min(w, h) * 0.037, 11, 16) + 'px';
    app.style.width = rot ? h + 'px' : ''; app.style.height = rot ? w + 'px' : '';
    window.dispatchEvent(new Event('crust-layout'));
  };
  window.addEventListener('resize', layout); layout();
  UI.screen('hub');
}
