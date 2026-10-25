/* ═══════════════════════════════════════════════════════════════════════
   Calebozolabs RENTALS — desk & my rentals
   The rental desk (categories → vehicle → period → pay → contract) and
   the renter's own rentals (time left, contract, GPS, extend).
   ═══════════════════════════════════════════════════════════════════════ */

const desk = () => S.data.location || { categories: [], vehicles: [] };
const deskCat = (id) => arr(desk().categories).find((c) => c.id === id) || {};
const myRentals = () => arr(S.data.rentals);

function cheapest(v) {
    const prices = S.durations.map((d) => v.prices && v.prices[d.id]).filter((p) => p != null);
    return prices.length ? Math.min(...prices) : 0;
}

function deskVehicles(catId) {
    const q = String(S.ui.deskQ || '').trim().toLowerCase();
    return arr(desk().vehicles).filter((v) => (!catId || v.category === catId)
        && (!q || v.label.toLowerCase().includes(q) || v.model.toLowerCase().includes(q)));
}

function selectedVehicle(list) {
    let v = list.find((x) => x.model === S.sel.model);
    if (!v && list.length) { v = list[0]; S.sel.model = v.model; S.sel.duration = null; }
    return v;
}

function firstDuration(v) {
    const d = S.durations.find((x) => v.prices && v.prices[x.id] != null);
    return d && d.id;
}

function account(id) { return arr(S.data.accounts).find((a) => a.id === id); }

/* ─── Desk page (all vehicles / one category) ─────────────────────── */

function vehicleCard(v, sel) {
    const cat = deskCat(v.category);
    const nolic = cat.license && !cat.licensed;
    return `<div class="card vcard ${sel ? 'sel' : ''} ${nolic ? 'nolic' : ''}" data-act="pickVehicle" data-model="${esc(v.model)}">
        ${thumb(v.image, '', cat.icon, `<div class="corner"><span class="chip sm">${catIcon(cat.icon, 10)}${esc(cat.label || '')}</span></div>${nolic ? `<div class="corner-r"><span class="chip sm warn">${I.id(10)}${esc(t('license_needed'))}</span></div>` : ''}`)}
        <div class="n">${esc(v.label)}</div>
        <div class="m"><span class="from">${esc(t('from'))}<b>${money(cheapest(v))}</b></span>
            <span class="chip sm">${esc(t('n_periods', S.durations.filter((d) => v.prices[d.id] != null).length))}</span></div>
    </div>`;
}

function deskSummary(v) {
    const cat = deskCat(v.category);
    if (!S.sel.duration || v.prices[S.sel.duration] == null) S.sel.duration = firstDuration(v);
    const accounts = arr(S.data.accounts);
    if (!S.sel.account || !account(S.sel.account)) S.sel.account = (accounts.find((a) => a.balance >= 0) || accounts[0] || {}).id;
    const dur = S.durations.find((d) => d.id === S.sel.duration) || {};
    const price = v.prices[S.sel.duration] || 0;
    const deposit = S.data.depositEnabled ? (v.deposit || 0) : 0;
    const total = price + deposit;
    const acc = account(S.sel.account);
    const atLimit = myRentals().length >= (S.data.maxActive || 1);
    const nolic = cat.license && !cat.licensed;
    const short = acc && acc.balance < total;
    const ex = S.data.expiry || {};

    let block = '';
    if (atLimit) block = `<div class="note warn">${esc(t('limit_note', S.data.maxActive || 1))} <a class="acc-t" data-nav="mine" style="cursor:pointer">${esc(t('nav_mine'))}</a></div>`;
    else if (nolic) block = `<div class="note bad">${esc(t('license_note'))}</div>`;
    else if (short) block = `<div class="note bad">${esc(t('short_note', money(total - acc.balance)))}</div>`;

    const policy = ex.mode === 'repossess' ? t('policy_repossess', ex.grace) : t('policy_recharge', money(price), durationLabel(dur.minutes));

    return `<div class="card detail" style="--cc-rgb:var(--accent-rgb)">
        <div class="dhead">${thumb(v.image, 'lg', cat.icon)}
            <div class="dtitle">${esc(v.label)}</div>
            <div class="dsub row" style="gap:6px"><span class="chip sm">${catIcon(cat.icon, 10)}${esc(cat.label || '')}</span>${deposit ? `<span class="chip sm accent">${I.shield(10)}${esc(t('deposit_n', money(deposit)))}</span>` : ''}</div>
        </div>
        <div class="dbody">
            <div><div class="sec-h">${esc(t('rental_period'))}</div>
                <div class="durs">${S.durations.map((d) => {
                    const p = v.prices[d.id];
                    return `<div class="dur ${p == null ? 'off' : ''} ${S.sel.duration === d.id ? 'on' : ''}" data-act="pickDuration" data-id="${esc(d.id)}">
                        <div class="ic">${I.clock(15)}</div><div class="k">${esc(shortDuration(d.minutes))}</div><div class="v">${p == null ? '—' : money(p)}</div></div>`;
                }).join('')}</div></div>
            <div><div class="sec-h">${esc(t('pay_with'))}</div>
                <div class="pay">${accounts.map((a) => `<div class="acc ${S.sel.account === a.id ? 'on' : ''} ${a.balance < total ? 'short' : ''}" data-act="pickAccount" data-id="${esc(a.id)}">
                    <span class="rad"></span>${accIcon(a.id, 14)}<span>${esc(t('acc_' + a.id))}</span><span class="bal">${money(a.balance)}</span></div>`).join('')}</div></div>
            <div class="kv">
                <div class="r"><span class="k">${esc(t('rental_n', durationLabel(dur.minutes)))}</span><span class="v">${money(price)}</span></div>
                ${S.data.depositEnabled ? `<div class="r"><span class="k">${esc(t('deposit_refundable'))}</span><span class="v">${money(deposit)}</span></div>` : ''}
                <div class="r sum"><span class="k">${esc(t('total_due'))}</span><span class="v acc-t">${money(total)}</span></div>
            </div>
            <div class="note blue">${esc(policy)}</div>
            ${block}
        </div>
        <div class="dfoot"><button class="btn primary block ${atLimit || nolic || short || !S.sel.duration ? 'disabled' : ''}" data-act="rent">${I.key(14)}${esc(t('rent_for', money(total)))}</button></div>
    </div>`;
}

function deskPage(catId) {
    const list = deskVehicles(catId);
    const v = selectedVehicle(list);
    const cat = catId ? deskCat(catId) : null;
    return `<div class="page-head"><div class="page-title">${cat ? catIcon(cat.icon, 16) : I.grid(16)}${esc(cat ? cat.label : t('nav_all'))}<span class="chip sm">${list.length}</span></div>
            <div class="side"><div class="search" style="width:230px">${I.search(14)}<input class="input" data-input="deskQ" data-focus="deskQ" placeholder="${esc(t('search_vehicles'))}" value="${esc(S.ui.deskQ || '')}"></div></div></div>
        <div class="page-body"><div class="desk">
            <div class="scroll">${list.length ? `<div class="vgrid two stagger">${list.map((x) => vehicleCard(x, v && x.model === v.model)).join('')}</div>` : empty(I.car, t('no_vehicles'))}</div>
            <div class="col" style="min-height:0">${v ? deskSummary(v) : ''}</div>
        </div></div>`;
}

PAGES.all = { icon: I.grid, label: () => t('nav_all'), render: () => deskPage(null), badge: () => `<span class="badge">${arr(desk().vehicles).length}</span>` };
PAGES.category = (id) => {
    const c = deskCat(id);
    return {
        icon: (s) => catIcon(c.icon, s), label: () => c.label || id, render: () => deskPage(id),
        badge: () => `<span class="badge">${arr(desk().vehicles).filter((v) => v.category === id).length}</span>`,
    };
};

inputs.deskQ = (el) => { S.ui.deskQ = el.value; rerenderKeepFocus(el); };

actions.pickVehicle = (el) => { S.sel.model = el.dataset.model; S.sel.duration = null; rerender(); };
actions.pickDuration = (el) => { S.sel.duration = el.dataset.id; rerender(); };
actions.pickAccount = (el) => { S.sel.account = el.dataset.id; rerender(); };

actions.rent = async (el) => {
    if (el.classList.contains('disabled')) return;
    const res = await act(el, 'rent', desk().id, S.sel.model, S.sel.duration, S.sel.account);
    if (!res.ok) {
        const fresh = await call('desk', desk().id);
        if (fresh.ok && fresh.data) { S.data = Object.assign(S.data, fresh.data); rerender(); }
        return;
    }
    close(false, true);
    if (res.data && res.data.contract) showContract(res.data.contract, false);
};

MODES.desk = {
    logo: I.key,
    first: () => 'all',
    init() { S.mine = null; },
    nav: () => [['all', ...arr(desk().categories).map((c) => 'cat:' + c.id)], ['mine']],
    title: () => desk().label || t('title'),
    subtitle: () => `<span class="bright">${esc(t('title'))}</span><span class="dim"> · ${esc(t('n_vehicles', arr(desk().vehicles).length))} · ${esc(t('n_categories', arr(desk().categories).length))}</span>`,
    navLabel: () => t('nav_label_desk'),
    stats: () => `<div class="header-stat"><div class="v ${myRentals().length ? 'acc-t' : ''}">${myRentals().length} / ${S.data.maxActive || 1}</div><div class="l">${esc(t('your_rentals'))}</div></div>`,
    onRentals: () => { if (S.page === 'mine') PAGES.mine.enter(); else rerender(); },
};

/* ─── My rentals ──────────────────────────────────────────────────── */

function rentalRow(r) {
    const canExtend = S.mine && S.mine.canExtend && arr(r.extend).length > 0;
    return `<div class="card rrow ${r.status === 'overdue' || r.expiresAt - nowSec() <= 0 ? 'overdue' : ''}">
        ${thumb(r.image, 'sm', 'car')}
        <div style="min-width:0"><div class="n">${esc(r.label)} ${statusPill(r.status)}</div>
            <div class="m">${plate(r.plate)}<span>${esc(r.locationLabel)}</span><span>·</span><span>${esc(r.durationLabel)}</span>
                ${r.recharges ? `<span class="chip sm warn">${esc(t('renewed_n', r.recharges))}</span>` : ''}<span class="chip sm">${esc(r.contract)}</span></div></div>
        ${timerBox(r)}
        <div class="acts">
            <button class="btn ghost sm" data-act="viewContract" data-id="${r.id}">${I.contract(13)}${esc(t('contract'))}</button>
            <button class="btn ghost sm" data-act="locate" data-id="${r.id}">${I.pin(13)}${esc(t('gps'))}</button>
            ${canExtend ? `<button class="btn primary sm" data-act="extend" data-id="${r.id}">${I.plusTime(13)}${esc(t('extend'))}</button>` : ''}
        </div>
    </div>`;
}

function minePage() {
    const m = S.mine;
    if (!m) return `<div class="loading-state">${esc(t('loading'))}</div>`;
    const rentals = arr(m.rentals);
    const history = arr(m.history);
    return `<div class="page-head"><div class="page-title">${I.key(16)}${esc(t('nav_mine'))}<span class="chip sm">${rentals.length}</span></div></div>
        <div class="page-body scroll">
            ${rentals.length ? `<div class="stack stagger">${rentals.map(rentalRow).join('')}</div>` : `<div class="card">${empty(I.key, t('no_rentals'))}</div>`}
            ${rentals.length ? `<div class="note blue" style="margin-top:12px">${esc(t('return_hint'))}</div>` : ''}
            ${m.canExtend === false && rentals.length ? `<div class="note" style="margin-top:8px">${esc(t('extend_at_desk_hint'))}</div>` : ''}
            <div class="sub-title" style="margin-top:22px">${esc(t('recent_rentals'))}</div>
            ${history.length ? `<div class="card pad"><table class="table"><thead><tr><th>${esc(t('h_contract'))}</th><th>${esc(t('h_vehicle'))}</th><th>${esc(t('h_desk'))}</th><th>${esc(t('h_status'))}</th><th class="num">${esc(t('h_paid'))}</th><th class="num">${esc(t('h_refund'))}</th><th></th></tr></thead><tbody>
                ${history.map((h) => `<tr class="click" data-act="viewContract" data-id="${h.id}"><td class="strong">${esc(h.contract)}</td><td>${esc(h.label)} ${plate(h.plate)}</td><td>${esc(h.locationLabel)}</td><td>${statusPill(h.status)}</td>
                    <td class="num">${money(h.paid)}</td><td class="num">${money(h.refund)}</td><td class="num dim">${esc(ago(h.endedAt))}</td></tr>`).join('')}
            </tbody></table></div>` : `<div class="card">${empty(I.history, t('no_history'))}</div>`}
        </div>`;
}

PAGES.mine = {
    icon: I.key, label: () => t('nav_mine'), render: minePage,
    badge: () => (myRentals().length ? `<span class="badge live">${myRentals().length}</span>` : ''),
    async enter() {
        if (S.ui.mineFresh) { S.ui.mineFresh = false; return; }   // just opened with this data
        const res = await call('mine');
        if (res.ok && res.data) {
            S.mine = res.data;
            syncClock(res.data.now);
            S.data.rentals = arr(res.data.rentals);
            if (S.page === 'mine') rerender();
        }
    },
};

actions.viewContract = async (el) => {
    const res = await call('contract', Number(el.dataset.id));
    if (res.ok && res.data) showContract(res.data, true);
    else toast(res.message || t('failed'), 'error');
};

actions.locate = async (el) => {
    const res = await call('locate', Number(el.dataset.id));
    if (res.ok && res.data) { nui('waypoint', res.data); toast(res.message, 'success'); }
    else toast(res.message || t('failed'), 'error');
};

actions.extend = (el) => {
    const r = arr(S.mine && S.mine.rentals).find((x) => x.id === Number(el.dataset.id));
    if (!r) return;
    const opts = arr(r.extend);
    let pick = opts[0] && opts[0].id;
    let acc = (arr(S.mine.accounts)[0] || {}).id;
    const draw = (box) => {
        box.querySelector('[data-slot=durs]').innerHTML = opts.map((o) => `<div class="dur ${pick === o.id ? 'on' : ''}" data-pick="${esc(o.id)}">
            <div class="ic">${I.clock(15)}</div><div class="k">${esc(shortDuration(o.minutes))}</div><div class="v">${money(o.price)}</div></div>`).join('');
        box.querySelector('[data-slot=pay]').innerHTML = arr(S.mine.accounts).map((a) => `<div class="acc ${acc === a.id ? 'on' : ''}" data-acc="${esc(a.id)}">
            <span class="rad"></span>${accIcon(a.id, 14)}<span>${esc(t('acc_' + a.id))}</span><span class="bal">${money(a.balance)}</span></div>`).join('');
        const o = opts.find((x) => x.id === pick);
        box.querySelector('[data-slot=total]').innerHTML = `<span class="k">${esc(t('extend_by', o ? durationLabel(o.minutes) : '—'))}</span><span class="v">${money(o ? o.price : 0)}</span>`;
    };
    modal({
        title: t('extend_title', r.label),
        body: `<div>${esc(t('extend_body'))}</div>
            <div class="durs" data-slot="durs"></div>
            <div class="pay" data-slot="pay"></div>
            <div class="total" data-slot="total"></div>`,
        confirm: t('extend'),
        onRender(box) {
            draw(box);
            box.addEventListener('click', (e) => {
                const d = e.target.closest('[data-pick]');
                const a = e.target.closest('[data-acc]');
                if (d) { pick = d.dataset.pick; draw(box); }
                if (a) { acc = a.dataset.acc; draw(box); }
            });
        },
        async onConfirm() {
            const res = await act(null, 'extend', r.id, pick, acc);
            if (res.ok) PAGES.mine.enter();
            return res.ok;
        },
    });
};

MODES.mine = {
    logo: I.contract,
    first: () => 'mine',
    nav: () => [['mine']],
    title: () => t('title_mine'),
    subtitle: () => `<span class="bright">${esc(t('n_active', myRentals().length))}</span><span class="dim"> · ${esc(t('mine_sub'))}</span>`,
    navLabel: () => t('nav_label_mine'),
    init() { S.mine = S.data; S.ui.mineFresh = true; },
    onRentals: () => PAGES.mine.enter(),
};
