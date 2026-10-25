/* ═══════════════════════════════════════════════════════════════════════
   Calebozolabs RENTALS — admin panel  (/rentaladmin)
   Desks, the desk editor (general · categories · vehicles · spawn
   points), live rentals, history and settings. The server validates every
   save again; this side only keeps the draft.
   ═══════════════════════════════════════════════════════════════════════ */

const AD = () => S.data;
const ED = () => S.ed || {};

async function reloadAdmin() {
    const res = await call('adminData');
    if (res.ok && res.data) {
        S.data = Object.assign(S.data, res.data);
        syncClock(res.data.now);
        rerender();
    }
}

function coordText(c) {
    if (!c) return `<span class="i">${esc(t('not_set'))}</span>`;
    return `${fmt(c.x, 2)}, ${fmt(c.y, 2)}, ${fmt(c.z, 2)} <span class="i">· ${fmt(c.w || 0, 0)}°</span>`;
}

/* ─── Desks list ──────────────────────────────────────────────────── */

function desksPage() {
    const list = arr(AD().locations);
    const st = AD().stats || {};
    return `<div class="page-head"><div class="page-title">${I.store(16)}${esc(t('nav_desks'))}<span class="chip sm">${list.length}</span></div>
            <div class="side"><button class="btn ghost sm" data-act="adminReload">${I.refresh(13)}${esc(t('refresh'))}</button>
            <button class="btn primary sm" data-act="newDesk">${I.plus(13)}${esc(t('new_desk'))}</button></div></div>
        <div class="page-body scroll">
            <div class="grid4 stagger" style="margin-bottom:14px">
                <div class="card kpi"><div class="l">${I.live(12)}${esc(t('k_active'))}</div><div class="v acc-t">${arr(AD().active).length}</div></div>
                <div class="card kpi"><div class="l">${I.key(12)}${esc(t('k_today'))}</div><div class="v">${fmt(st.today)}</div><div class="s">${esc(t('k_total_n', fmt(st.total)))}</div></div>
                <div class="card kpi"><div class="l">${I.cash(12)}${esc(t('k_revenue_today'))}</div><div class="v">${money(st.todayRevenue)}</div><div class="s">${esc(t('k_revenue_all', money(st.revenue)))}</div></div>
                <div class="card kpi"><div class="l">${I.alert(12)}${esc(t('k_repossessed'))}</div><div class="v ${st.repossessed ? 'warn-t' : ''}">${fmt(st.repossessed)}</div></div>
            </div>
            ${list.length ? `<div class="stack stagger">${list.map((l) => `<div class="card dcard ${l.enabled ? '' : 'off'}">
                <div class="ic-tile">${I.store(19)}</div>
                <div style="min-width:0"><div class="n">${esc(l.label)} ${l.enabled ? '' : `<span class="chip sm">${esc(t('disabled'))}</span>`}</div>
                    <div class="m"><span class="chip sm">${esc(t('n_categories', arr(l.categories).length))}</span><span class="chip sm">${esc(t('n_vehicles', arr(l.vehicles).length))}</span>
                    <span class="chip sm">${esc(t('n_spawns', arr(l.spawns).length))}</span>${(AD().activeAt || {})[l.id] ? `<span class="chip sm live good">${esc(t('n_out', AD().activeAt[l.id]))}</span>` : ''}</div></div>
                <div class="acts"><button class="btn ghost sm" data-act="tpTo" data-x="${l.ped.coords.x}" data-y="${l.ped.coords.y}" data-z="${l.ped.coords.z}">${I.tp(13)}</button>
                    <button class="btn primary sm" data-act="editDesk" data-id="${esc(l.id)}">${I.edit(13)}${esc(t('edit'))}</button></div>
            </div>`).join('')}</div>` : `<div class="card">${empty(I.store, t('no_desks'))}</div>`}
        </div>`;
}

PAGES.desks = { icon: I.store, label: () => t('nav_desks'), render: desksPage, badge: () => `<span class="badge">${arr(AD().locations).length}</span>` };

actions.adminReload = () => reloadAdmin();
actions.tpTo = (el) => nui('teleport', { x: Number(el.dataset.x), y: Number(el.dataset.y), z: Number(el.dataset.z) });

actions.newDesk = async () => {
    const here = await nui('here');
    const d = AD().defaults || {};
    S.ed = {
        id: null, tab: 'general', dirty: true,
        loc: {
            label: t('new_desk_label'), enabled: true, radius: d.radius || 30,
            ped: { model: d.ped || 'a_m_y_business_03', coords: here || null },
            blip: Object.assign({ enabled: true, sprite: 225, color: 5, scale: 0.75 }, d.blip || {}),
            spawns: [], categories: [{ id: 'cars', label: t('default_category'), icon: 'car' }], vehicles: [],
        },
    };
    go('editor');
};

actions.editDesk = (el) => {
    const loc = arr(AD().locations).find((l) => l.id === el.dataset.id);
    if (!loc) return;
    S.ed = { id: loc.id, tab: 'general', dirty: false, loc: JSON.parse(JSON.stringify(loc)) };
    go('editor');
};

/* ─── Desk editor ─────────────────────────────────────────────────── */

function dirty() { S.ed.dirty = true; }

function edGeneral(l) {
    return `<div class="card ed-sec">
            <div class="sec-h">${esc(t('ed_desk'))}</div>
            <div class="row2"><div class="field"><label>${esc(t('f_label'))}</label><input class="input" maxlength="48" data-input="edLabel" data-focus="edLabel" value="${esc(l.label)}"></div>
                <div class="field"><label>${esc(t('f_status'))}</label><div style="height:32px;display:flex;align-items:center">${toggle('edEnabled', l.enabled, t('open_for_rentals'))}</div></div></div>
        </div>
        <div class="card ed-sec">
            <div class="sec-h">${esc(t('ed_agent'))}</div>
            <div class="row2"><div class="field"><label>${esc(t('f_ped'))}</label><input class="input" data-change="edPed" value="${esc(l.ped.model)}"><div class="hint">${esc(t('f_ped_hint'))}</div></div>
                <div class="field"><label>${esc(t('f_return_radius'))}</label><div class="row"><input type="range" min="5" max="100" step="1" value="${l.radius}" data-input="edRadius"><span class="mono" id="radiusVal" style="width:54px;text-align:right;white-space:nowrap">${fmt(l.radius)} m</span></div><div class="hint">${esc(t('f_return_radius_hint'))}</div></div></div>
            <div class="field"><label>${esc(t('f_agent_pos'))}</label>
                <div class="coord ${l.ped.coords ? '' : 'missing'}">${I.pin(13)}<span>${coordText(l.ped.coords)}</span><div class="acts">
                    <button class="btn ghost xs" data-act="pedHere">${I.here(12)}${esc(t('use_my_pos'))}</button>
                    <button class="btn ghost xs" data-act="pedAim">${I.target(12)}${esc(t('aim'))}</button>
                    ${l.ped.coords ? `<button class="btn ghost xs" data-act="tpTo" data-x="${l.ped.coords.x}" data-y="${l.ped.coords.y}" data-z="${l.ped.coords.z}">${I.tp(12)}</button>` : ''}</div></div></div>
        </div>
        <div class="card ed-sec">
            <div class="sec-h">${esc(t('ed_blip'))}<span>${toggle('edBlip', l.blip.enabled, t('show_on_map'))}</span></div>
            <div class="row3"><div class="field"><label>${esc(t('f_sprite'))}</label><input class="input" type="number" min="1" max="900" data-change="edBlipNum" data-k="sprite" value="${l.blip.sprite}"></div>
                <div class="field"><label>${esc(t('f_colour'))}</label><input class="input" type="number" min="0" max="85" data-change="edBlipNum" data-k="color" value="${l.blip.color}"></div>
                <div class="field"><label>${esc(t('f_scale'))}</label><input class="input" type="number" min="0.3" max="2" step="0.05" data-change="edBlipNum" data-k="scale" value="${l.blip.scale}"></div></div>
            <div class="hint" style="font-family:var(--medium);font-size:11px;color:var(--text-4)">${esc(t('f_blip_hint'))}</div>
        </div>`;
}

const licenseSelect = (cur, i) => `<select class="input sm" data-change="catLicense" data-i="${i}"><option value="">${esc(t('no_license'))}</option>${arr(AD().licenses).map((k) => `<option value="${esc(k)}" ${cur === k ? 'selected' : ''}>${esc(t('lic_' + k))}</option>`).join('')}</select>`;

function edCategories(l) {
    return `<div class="toolbar"><div class="grow note">${esc(t('cats_hint'))}</div><button class="btn primary sm" data-act="catAdd">${I.plus(13)}${esc(t('add_category'))}</button></div>
        <div class="stack">${arr(l.categories).map((c, i) => `<div class="card cat-row">
            <button class="ic-tile sm" data-act="catIcon" data-i="${i}" data-tip="${esc(t('change_icon'))}">${catIcon(c.icon, 16)}</button>
            <div><input class="input sm" maxlength="32" data-input="catLabel" data-i="${i}" data-focus="cat${i}" value="${esc(c.label)}">
                <div class="hint" style="margin-top:5px;font-family:var(--medium);font-size:10.5px;color:var(--text-4)">${esc(t('n_vehicles', arr(l.vehicles).filter((v) => v.category === c.id).length))}</div></div>
            ${licenseSelect(c.license, i)}
            <div class="row" style="gap:4px"><button class="btn ghost xs" data-act="catMove" data-i="${i}" data-d="-1" ${i === 0 ? 'disabled' : ''}>${I.up(11)}</button>
                <button class="btn ghost xs" data-act="catMove" data-i="${i}" data-d="1" ${i === l.categories.length - 1 ? 'disabled' : ''}>${I.down(11)}</button>
                <button class="btn danger xs" data-act="catDel" data-i="${i}">${I.trash(11)}</button></div>
        </div>`).join('')}</div>`;
}

function edVehicles(l) {
    const cats = arr(l.categories);
    const cols = S.durations.length;
    const groups = cats.map((c) => ({ c, list: arr(l.vehicles).map((v, i) => ({ v, i })).filter((x) => x.v.category === c.id) }));
    const depDefault = (AD().defaults || {}).deposit || 0;
    return `<div class="toolbar"><div class="grow note">${esc(t('veh_hint'))}</div><button class="btn primary sm" data-act="vehAdd">${I.plus(13)}${esc(t('add_vehicle'))}</button></div>
        ${arr(l.vehicles).length ? groups.filter((g) => g.list.length).map((g) => `<div class="cat-group"><div class="h">${catIcon(g.c.icon, 13)}${esc(g.c.label)}<span class="chip sm">${g.list.length}</span></div>
            <div class="stack">${g.list.map(({ v, i }) => `<div class="card veh-row">
                ${thumb(v.image || (S.imagePath ? S.imagePath.replace('%s', v.model) : null), 'xs', g.c.icon)}
                <div style="min-width:0">
                    <div class="top"><input class="input sm" maxlength="48" data-input="vehLabel" data-i="${i}" data-focus="vl${i}" value="${esc(v.label)}">
                        <span class="chip sm mono">${esc(v.model)}</span><span class="chip sm">${esc(t('type_' + (v.type || 'automobile')))}</span>
                        <button class="btn danger xs" data-act="vehDel" data-i="${i}">${I.trash(11)}</button></div>
                    <div class="prices" style="--cols:${cols}">
                        ${S.durations.map((d) => `<div class="field"><label>${esc(shortDuration(d.minutes))}</label><div class="money-in" data-cur="${esc(S.currency)}"><input class="input sm" type="number" min="0" placeholder="—" data-change="vehPrice" data-i="${i}" data-d="${esc(d.id)}" value="${v.prices && v.prices[d.id] != null ? v.prices[d.id] : ''}"></div></div>`).join('')}
                        <div class="field"><label>${esc(t('f_deposit'))}</label><div class="money-in" data-cur="${esc(S.currency)}"><input class="input sm" type="number" min="0" placeholder="${depDefault}" data-change="vehDeposit" data-i="${i}" value="${v.deposit != null ? v.deposit : ''}"></div></div>
                        <div class="field"><label>${esc(t('f_category'))}</label><select class="input sm" data-change="vehCat" data-i="${i}">${cats.map((c) => `<option value="${esc(c.id)}" ${c.id === v.category ? 'selected' : ''}>${esc(c.label)}</option>`).join('')}</select></div>
                    </div>
                </div></div>`).join('')}</div></div>`).join('') : `<div class="card">${empty(I.car, t('no_vehicles_yet'))}</div>`}`;
}

function edSpawns(l) {
    return `<div class="toolbar"><div class="grow note">${esc(t('spawns_hint'))}</div>
            <button class="btn ghost sm" data-act="spawnHere">${I.here(13)}${esc(t('use_my_pos'))}</button>
            <button class="btn primary sm" data-act="spawnAim">${I.target(13)}${esc(t('aim_place'))}</button></div>
        ${arr(l.spawns).length ? `<div class="stack">${l.spawns.map((p, i) => `<div class="coord">${I.car(14)}<span class="mono">#${i + 1}</span><span>${coordText(p)}</span><div class="acts">
            <button class="btn ghost xs" data-act="spawnRe" data-i="${i}">${I.target(12)}${esc(t('move'))}</button>
            <button class="btn ghost xs" data-act="tpTo" data-x="${p.x}" data-y="${p.y}" data-z="${p.z + 1}">${I.tp(12)}</button>
            <button class="btn danger xs" data-act="spawnDel" data-i="${i}">${I.trash(12)}</button></div></div>`).join('')}</div>` : `<div class="card">${empty(I.pin, t('no_spawns'))}</div>`}`;
}

function edChecks(l) {
    const priced = arr(l.vehicles).filter((v) => Object.values(v.prices || {}).some((p) => p !== '' && p != null));
    return [
        [String(l.label || '').trim().length >= 2, t('chk_label')],
        [!!l.ped.coords, t('chk_agent')],
        [arr(l.spawns).length > 0, t('chk_spawn')],
        [arr(l.categories).length > 0, t('chk_category')],
        [arr(l.vehicles).length > 0 && priced.length === arr(l.vehicles).length, t('chk_vehicles')],
    ];
}

function editorPage() {
    const e = ED();
    const l = e.loc;
    if (!l) return desksPage();
    const tabs = [['general', t('tab_general')], ['categories', t('tab_categories'), arr(l.categories).length], ['vehicles', t('tab_vehicles'), arr(l.vehicles).length], ['spawns', t('tab_spawns'), arr(l.spawns).length]];
    const body = { general: edGeneral, categories: edCategories, vehicles: edVehicles, spawns: edSpawns }[e.tab] || edGeneral;
    const checks = edChecks(l);
    const ready = checks.every((c) => c[0]);
    return `<div class="page-head"><div class="page-title"><button class="btn ghost xs" data-act="edBack">${I.arrowL(12)}</button>${esc(e.id ? t('edit_desk') : t('new_desk'))}
            ${e.dirty ? `<span class="unsaved">${esc(t('unsaved'))}</span>` : ''}</div>
            <div class="side"><div class="seg">${tabs.map(([id, label, n]) => `<button class="${e.tab === id ? 'on' : ''}" data-act="edTab" data-id="${id}">${esc(label)}${n != null ? `<span class="n">${n}</span>` : ''}</button>`).join('')}</div></div></div>
        <div class="page-body"><div class="ed">
            <div class="scroll">${body(l)}</div>
            <div class="ed-side">
                <div class="card"><div class="sec-h">${esc(t('ed_checklist'))}</div><div class="checklist">${checks.map(([ok, label]) => `<div class="c ${ok ? 'ok' : ''}"><i>${I.check(10)}</i>${esc(label)}</div>`).join('')}</div></div>
                <div class="card"><div class="sec-h">${esc(t('ed_summary'))}</div><div class="kv">
                    <div class="r"><span class="k">${esc(t('f_label'))}</span><span class="v">${esc(l.label)}</span></div>
                    <div class="r"><span class="k">${esc(t('tab_categories'))}</span><span class="v">${arr(l.categories).length}</span></div>
                    <div class="r"><span class="k">${esc(t('tab_vehicles'))}</span><span class="v">${arr(l.vehicles).length}</span></div>
                    <div class="r"><span class="k">${esc(t('tab_spawns'))}</span><span class="v">${arr(l.spawns).length}</span></div>
                    <div class="r"><span class="k">${esc(t('f_return_radius'))}</span><span class="v">${fmt(l.radius)} m</span></div></div></div>
                <button class="btn primary block ${ready ? '' : 'disabled'}" data-act="edSave">${I.check(13)}${esc(t('save_desk'))}</button>
                ${e.id ? `<button class="btn danger block" data-act="edDelete">${I.trash(13)}${esc(t('delete_desk'))}</button>` : ''}
            </div>
        </div></div>`;
}

PAGES.editor = { icon: I.edit, label: () => t('nav_desks'), parent: 'desks', render: editorPage };

actions.edTab = (el) => { S.ed.tab = el.dataset.id; rerender(); };
actions.edBack = () => {
    if (!S.ed.dirty) { S.ed = null; return go('desks'); }
    confirmBox(t('discard_title'), esc(t('discard_body')), t('discard'), 'danger', async () => { S.ed = null; go('desks'); });
};

inputs.edLabel = (el) => { S.ed.loc.label = el.value; dirty(); rerenderKeepFocus(el); };
inputs.edRadius = (el) => { S.ed.loc.radius = Number(el.value); dirty(); const v = $('#radiusVal'); if (v) v.textContent = `${el.value} m`; };
changes.edRadius = () => rerender();
toggles.edEnabled = (on) => { S.ed.loc.enabled = on; dirty(); rerender(); };
toggles.edBlip = (on) => { S.ed.loc.blip.enabled = on; dirty(); rerender(); };
changes.edBlipNum = (el) => { S.ed.loc.blip[el.dataset.k] = Number(el.value); dirty(); rerender(); };
changes.edPed = async (el) => {
    const model = el.value.trim().toLowerCase();
    const res = await nui('modelInfo', { model, kind: 'ped' });
    if (res && res.ok === false) { toast(res.message, 'error'); el.value = S.ed.loc.ped.model; return; }
    S.ed.loc.ped.model = model; dirty(); rerender();
};

actions.pedHere = async () => { const c = await nui('here'); if (c) { S.ed.loc.ped.coords = c; dirty(); rerender(); } };
actions.pedAim = async () => { const c = await nui('place', { kind: 'ped', model: S.ed.loc.ped.model }); if (c) { S.ed.loc.ped.coords = c; dirty(); rerender(); } };

/* categories */
const slugify = (s) => String(s || '').toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '').slice(0, 32) || 'category';

actions.catAdd = () => {
    const l = S.ed.loc;
    let id = 'category', n = 1;
    while (l.categories.some((c) => c.id === id)) id = `category_${++n}`;
    l.categories.push({ id, label: t('new_category'), icon: 'car' });
    dirty(); rerender();
};
inputs.catLabel = (el) => { S.ed.loc.categories[Number(el.dataset.i)].label = el.value; dirty(); };
changes.catLabel = () => rerender();
changes.catLicense = (el) => { const c = S.ed.loc.categories[Number(el.dataset.i)]; c.license = el.value || null; dirty(); };
actions.catMove = (el) => {
    const list = S.ed.loc.categories, i = Number(el.dataset.i), j = i + Number(el.dataset.d);
    if (j < 0 || j >= list.length) return;
    [list[i], list[j]] = [list[j], list[i]];
    dirty(); rerender();
};
actions.catDel = (el) => {
    const l = S.ed.loc, i = Number(el.dataset.i), c = l.categories[i];
    if (l.categories.length <= 1) return toast(t('need_one_category'), 'error');
    const used = l.vehicles.filter((v) => v.category === c.id).length;
    const doIt = () => { l.categories.splice(i, 1); l.vehicles = l.vehicles.filter((v) => v.category !== c.id); dirty(); rerender(); };
    if (!used) return doIt();
    confirmBox(t('del_category_title'), esc(t('del_category_body', c.label, used)), t('delete'), 'danger', async () => doIt());
};
actions.catIcon = (el) => {
    const c = S.ed.loc.categories[Number(el.dataset.i)];
    modal({
        title: t('pick_icon'), noFoot: true,
        body: `<div class="icon-pick">${arr(AD().icons).map((ic) => `<button class="${c.icon === ic ? 'on' : ''}" data-ic="${esc(ic)}">${catIcon(ic, 16)}</button>`).join('')}</div>`,
        onRender(box) {
            box.addEventListener('click', (e) => {
                const b = e.target.closest('[data-ic]');
                if (!b) return;
                c.icon = b.dataset.ic; dirty(); closeModal(); rerender();
            });
        },
    });
};

/* vehicles */
actions.vehAdd = () => {
    const cats = arr(S.ed.loc.categories);
    modal({
        title: t('add_vehicle'),
        body: `<div class="field"><label>${esc(t('f_model'))}</label><input class="input" id="vehModel" placeholder="sultan" autocomplete="off"><div class="hint">${esc(t('f_model_hint'))}</div></div>
            <div class="field"><label>${esc(t('f_category'))}</label><select class="input" id="vehCat">${cats.map((c) => `<option value="${esc(c.id)}">${esc(c.label)}</option>`).join('')}</select></div>
            <div class="row3">${S.durations.map((d) => `<div class="field"><label>${esc(shortDuration(d.minutes))}</label><div class="money-in" data-cur="${esc(S.currency)}"><input class="input" type="number" min="0" data-newprice="${esc(d.id)}" placeholder="—"></div></div>`).join('')}</div>`,
        confirm: t('add'),
        async onConfirm(box) {
            const model = box.querySelector('#vehModel').value.trim().toLowerCase();
            if (!model) return false;
            if (S.ed.loc.vehicles.some((v) => v.model === model)) { toast(t('err_model_twice_ui', model), 'error'); return false; }
            const res = await nui('modelInfo', { model, kind: 'vehicle' });
            if (!res || res.ok === false) { toast((res && res.message) || t('failed'), 'error'); return false; }
            const prices = {};
            box.querySelectorAll('[data-newprice]').forEach((inp) => { if (inp.value !== '') prices[inp.dataset.newprice] = Math.max(0, Math.floor(Number(inp.value))); });
            S.ed.loc.vehicles.push({ model: res.data.model, label: res.data.label, type: res.data.type, category: box.querySelector('#vehCat').value, prices });
            dirty(); rerender();
            return true;
        },
    });
};
inputs.vehLabel = (el) => { S.ed.loc.vehicles[Number(el.dataset.i)].label = el.value; dirty(); };
changes.vehPrice = (el) => {
    const v = S.ed.loc.vehicles[Number(el.dataset.i)];
    v.prices = v.prices || {};
    if (el.value === '') delete v.prices[el.dataset.d]; else v.prices[el.dataset.d] = Math.max(0, Math.floor(Number(el.value)));
    dirty(); rerender();
};
changes.vehDeposit = (el) => {
    const v = S.ed.loc.vehicles[Number(el.dataset.i)];
    if (el.value === '') delete v.deposit; else v.deposit = Math.max(0, Math.floor(Number(el.value)));
    dirty();
};
changes.vehCat = (el) => { S.ed.loc.vehicles[Number(el.dataset.i)].category = el.value; dirty(); rerender(); };
actions.vehDel = (el) => { S.ed.loc.vehicles.splice(Number(el.dataset.i), 1); dirty(); rerender(); };

/* spawn points */
const previewModel = () => { const v = arr(S.ed.loc.vehicles)[0]; return v ? v.model : 'sultan'; };
actions.spawnHere = async () => { const c = await nui('here'); if (c) { S.ed.loc.spawns.push(c); dirty(); rerender(); } };
actions.spawnAim = async () => { const c = await nui('place', { kind: 'spawn', model: previewModel() }); if (c) { S.ed.loc.spawns.push(c); dirty(); rerender(); } };
actions.spawnRe = async (el) => { const c = await nui('place', { kind: 'spawn', model: previewModel() }); if (c) { S.ed.loc.spawns[Number(el.dataset.i)] = c; dirty(); rerender(); } };
actions.spawnDel = (el) => { S.ed.loc.spawns.splice(Number(el.dataset.i), 1); dirty(); rerender(); };

/* save / delete */
actions.edSave = async (el) => {
    if (el.classList.contains('disabled')) return;
    const res = await act(el, 'adminSaveLocation', S.ed.loc, S.ed.id);
    if (!res.ok || !res.data) return;
    S.data.locations = arr(res.data.locations);
    S.ed.id = res.data.id;
    const saved = S.data.locations.find((x) => x.id === res.data.id);
    if (saved) S.ed.loc = JSON.parse(JSON.stringify(saved));
    S.ed.dirty = false;
    rerender();
};
actions.edDelete = () => {
    const e = ED();
    confirmBox(t('delete_desk'), esc(t('delete_desk_body', e.loc.label)), t('delete'), 'danger', async () => {
        const res = await act(null, 'adminDeleteLocation', e.id);
        if (res.ok && res.data) { S.data.locations = arr(res.data.locations); S.ed = null; go('desks'); }
    });
};

/* ─── Live rentals ────────────────────────────────────────────────── */

function livePage() {
    const list = arr(AD().active);
    return `<div class="page-head"><div class="page-title">${I.live(16)}${esc(t('nav_live'))}<span class="chip sm">${list.length}</span></div>
            <div class="side"><button class="btn ghost sm" data-act="adminReload">${I.refresh(13)}${esc(t('refresh'))}</button></div></div>
        <div class="page-body scroll">${list.length ? `<div class="card pad"><table class="table"><thead><tr>
            <th>${esc(t('h_contract'))}</th><th>${esc(t('h_renter'))}</th><th>${esc(t('h_vehicle'))}</th><th>${esc(t('h_desk'))}</th><th>${esc(t('h_status'))}</th><th class="num">${esc(t('time_left'))}</th><th class="num">${esc(t('h_paid'))}</th><th></th></tr></thead><tbody>
            ${list.map((r) => `<tr><td class="strong">${esc(r.contract)}</td><td>${r.online ? '<span class="dot-on"></span> ' : ''}${esc(r.name)}</td><td>${esc(r.label)} ${plate(r.plate)}</td>
                <td>${esc(r.locationLabel)}</td><td>${statusPill(r.status)}${r.recharges ? ` <span class="chip sm warn">×${r.recharges}</span>` : ''}</td>
                <td class="num mono" data-exp="${r.expiresAt}" data-len="1">${countdown(r.expiresAt - nowSec())}</td><td class="num">${money(r.paid)}</td>
                <td class="num"><button class="btn ghost xs" data-act="viewContract" data-id="${r.id}">${I.contract(11)}</button> <button class="btn danger xs" data-act="adminEnd" data-id="${r.id}" data-label="${esc(r.label)}" data-name="${esc(r.name)}">${esc(t('end'))}</button></td></tr>`).join('')}
            </tbody></table></div>` : `<div class="card">${empty(I.live, t('no_live'))}</div>`}</div>`;
}

PAGES.live = { icon: I.live, label: () => t('nav_live'), render: livePage, badge: () => (arr(AD().active).length ? `<span class="badge live">${arr(AD().active).length}</span>` : '') };

actions.adminEnd = (el) => confirmBox(t('end_title'), esc(t('end_body', el.dataset.label, el.dataset.name)), t('end'), 'danger', async () => {
    const res = await act(null, 'adminEndRental', Number(el.dataset.id));
    if (res.ok) reloadAdmin();
});

/* ─── History ─────────────────────────────────────────────────────── */

function historyPage() {
    const q = String(S.ui.histQ || '').trim().toLowerCase();
    const list = arr(AD().history).filter((h) => !q || [h.name, h.label, h.plate, h.contract, h.locationLabel].some((x) => String(x || '').toLowerCase().includes(q)));
    return `<div class="page-head"><div class="page-title">${I.history(16)}${esc(t('nav_history'))}<span class="chip sm">${list.length}</span></div>
            <div class="side"><div class="search" style="width:240px">${I.search(14)}<input class="input" data-input="histQ" data-focus="histQ" placeholder="${esc(t('search_history'))}" value="${esc(S.ui.histQ || '')}"></div></div></div>
        <div class="page-body scroll">${list.length ? `<div class="card pad"><table class="table"><thead><tr>
            <th>${esc(t('h_contract'))}</th><th>${esc(t('h_renter'))}</th><th>${esc(t('h_vehicle'))}</th><th>${esc(t('h_desk'))}</th><th>${esc(t('h_status'))}</th><th class="num">${esc(t('h_paid'))}</th><th class="num">${esc(t('h_refund'))}</th><th class="num">${esc(t('h_when'))}</th></tr></thead><tbody>
            ${list.map((h) => `<tr class="click" data-act="viewContract" data-id="${h.id}"><td class="strong">${esc(h.contract)}</td><td>${esc(h.name)}</td><td>${esc(h.label)} ${plate(h.plate)}</td><td>${esc(h.locationLabel)}</td>
                <td>${statusPill(h.status)}${h.recharges ? ` <span class="chip sm warn">×${h.recharges}</span>` : ''}</td><td class="num">${money(h.paid)}</td><td class="num">${money(h.refund)}</td><td class="num dim">${esc(ago(h.startedAt))}</td></tr>`).join('')}
            </tbody></table></div>` : `<div class="card">${empty(I.history, t('no_history'))}</div>`}</div>`;
}

PAGES.history = { icon: I.history, label: () => t('nav_history'), render: historyPage };
inputs.histQ = (el) => { S.ui.histQ = el.value; rerenderKeepFocus(el); };

/* ─── Settings ────────────────────────────────────────────────────── */

const SET_GROUPS = ['rentals', 'deposit', 'expiry', 'return', 'contract'];

function settingControl(r) {
    const k = esc(r.key);
    if (r.type === 'bool') return toggle('setBool:' + r.key, r.value === true);
    if (r.type === 'select') return `<select class="input" data-change="setVal" data-key="${k}">${arr(r.options).map((o) => `<option value="${esc(o)}" ${o === r.value ? 'selected' : ''}>${esc(t('opt_' + o))}</option>`).join('')}</select>`;
    if (r.type === 'list') return `<input class="input" data-change="setList" data-key="${k}" value="${esc(arr(r.value).join(', '))}">`;
    if (r.type === 'int') return `<input class="input" type="number" min="${r.min}" max="${r.max}" data-change="setNum" data-key="${k}" value="${r.value}">`;
    return `<input class="input" maxlength="${r.max || 32}" data-change="setVal" data-key="${k}" value="${esc(r.value)}">`;
}

function settingsPage() {
    const rows = arr(AD().settings);
    return `<div class="page-head"><div class="page-title">${I.gear(16)}${esc(t('nav_settings'))}</div></div>
        <div class="page-body scroll"><div class="note blue" style="margin-bottom:12px">${esc(t('settings_hint'))}</div>
        ${SET_GROUPS.map((g) => {
            const list = rows.filter((r) => r.group === g);
            if (!list.length) return '';
            return `<div class="sub-title">${esc(t('sg_' + g))}</div><div class="card cfg-group">${list.map((r) => `<div class="cfg-row ${r.changed ? 'dirty' : ''}">
                <div class="grow"><div class="cfg-l">${esc(t('set_' + r.key))}${r.changed ? `<span class="chip sm accent">${esc(t('edited'))}</span>` : ''}</div><div class="cfg-h">${esc(t('seth_' + r.key))}</div></div>
                <div class="cfg-c">${settingControl(r)}${r.changed ? `<button class="btn ghost xs cfg-rs" data-act="setReset" data-key="${esc(r.key)}" data-tip="${esc(t('reset_to', Array.isArray(r.default) ? r.default.join(', ') : String(r.default)))}">${I.refresh(11)}</button>` : ''}</div></div>`).join('')}</div>`;
        }).join('')}</div>`;
}

PAGES.settings = { icon: I.gear, label: () => t('nav_settings'), render: settingsPage };

async function saveSetting(key, value) {
    const res = await act(null, 'adminSetting', key, value);
    if (res.data && res.data.settings) S.data.settings = arr(res.data.settings);
    rerender();
}
toggles.setBool = (on, el) => saveSetting(el.dataset.toggle.slice('setBool:'.length), on);
changes.setVal = (el) => saveSetting(el.dataset.key, el.value);
changes.setNum = (el) => saveSetting(el.dataset.key, Number(el.value));
changes.setList = (el) => saveSetting(el.dataset.key, el.value.split(/[,\s]+/).filter(Boolean).map(Number));
actions.setReset = async (el) => {
    const res = await act(null, 'adminResetSetting', el.dataset.key);
    if (res.data && res.data.settings) S.data.settings = arr(res.data.settings);
    rerender();
};

/* ─── Mode ────────────────────────────────────────────────────────── */

MODES.admin = {
    logo: I.gear,
    first: () => 'desks',
    nav: () => [['desks'], ['live', 'history'], ['settings']],
    title: () => t('title_admin'),
    subtitle: () => `<span class="bright">${esc(t('n_desks', arr(AD().locations).length))}</span><span class="dim"> · ${esc(t('n_active', arr(AD().active).length))}</span>`,
    navLabel: () => t('nav_label_admin'),
    stats: () => `<div class="header-stat"><div class="v acc-t">${money((AD().stats || {}).todayRevenue)}</div><div class="l">${esc(t('k_revenue_today'))}</div></div>`,
    init() { S.ed = null; },
    beforeClose() {
        if (!S.ed || !S.ed.dirty) return true;
        confirmBox(t('discard_title'), esc(t('discard_body')), t('discard'), 'danger', async () => { S.ed = null; close(); });
        return false;
    },
};

/* ═══════════════════════════════════════════════════════════════════════
   BROWSER PREVIEW (open web/index.html without the game)
   ?mode=desk | mine | admin   &page=editor&tab=vehicles   &contract=1
   ═══════════════════════════════════════════════════════════════════════ */

window.Preview = {
    handle(name, data) {
        const args = (data && data.args) || [];
        const now = Math.floor(Date.now() / 1000);
        if (name === 'call') {
            if (args[0] === undefined && data.name === 'mine') return { ok: true, data: Preview.mine() };
            if (data.name === 'mine') return { ok: true, data: Preview.mine() };
            if (data.name === 'contract') return { ok: true, data: Preview.contract() };
            if (data.name === 'rent') return { ok: true, message: 'You rented a Karin Sultan — plate RENT4821.', data: { contract: Preview.contract() } };
            if (data.name === 'adminSaveLocation') return { ok: true, message: 'Desk saved.', data: { id: 'legion', locations: Preview.admin().locations } };
            return { ok: true, message: 'Done.', data: null };
        }
        if (name === 'here') return { x: 215.95, y: -809.7, z: 30.73, w: 248 };
        if (name === 'place') return { x: 220.1, y: -805.3, z: 30.2, w: 160 };
        if (name === 'modelInfo') return { ok: true, data: { model: data.model, label: data.model.charAt(0).toUpperCase() + data.model.slice(1), type: 'automobile' } };
        void now;
        return { ok: true };
    },
    img: (m) => `https://docs.fivem.net/vehicles/${m}.webp`,
    location() {
        const img = Preview.img;
        const v = (model, label, category, p, deposit = 250) => ({ model, label, category, type: 'automobile', image: img(model), deposit, prices: { '30m': p[0], '1h': p[1], '3h': p[2] } });
        return {
            id: 'legion', label: 'Legion Square Rentals',
            categories: [
                { id: 'economy', label: 'Economy', icon: 'car', licensed: true }, { id: 'sport', label: 'Sport', icon: 'sport', licensed: true },
                { id: 'bikes', label: 'Motorcycles', icon: 'bike', license: 'bike', licensed: false }, { id: 'utility', label: 'Utility', icon: 'van', licensed: true },
            ],
            vehicles: [
                v('panto', 'Benefactor Panto', 'economy', [150, 250, 600]), v('asbo', 'Maxwell Asbo', 'economy', [175, 300, 700]),
                v('blista', 'Dinka Blista', 'economy', [200, 350, 800]), v('sultan', 'Karin Sultan', 'sport', [450, 800, 1900], 750),
                v('elegy2', 'Annis Elegy RH8', 'sport', [600, 1050, null], 1000), v('faggio', 'Pegassi Faggio', 'bikes', [100, 175, 400]),
                v('bati', 'Pegassi Bati 801', 'bikes', [350, 600, 1400], 500), v('bison', 'Bravado Bison', 'utility', [250, 450, 1050]),
                v('speedo', 'Vapid Speedo', 'utility', [275, 475, 1100]),
            ],
        };
    },
    rentals() {
        const now = Math.floor(Date.now() / 1000);
        return [
            { id: 42, contract: 'CR-000042', label: 'Karin Sultan', model: 'sultan', plate: 'RENT4821', image: Preview.img('sultan'), location: 'legion', locationLabel: 'Legion Square Rentals', category: 'Sport', minutes: 60, durationLabel: '1 hour', price: 800, deposit: 750, paid: 800, startedAt: now - 2900, expiresAt: now + 700, status: 'active', recharges: 0,
              extend: [{ id: '30m', minutes: 30, price: 450 }, { id: '1h', minutes: 60, price: 800 }, { id: '3h', minutes: 180, price: 1900 }] },
            { id: 43, contract: 'CR-000043', label: 'Pegassi Faggio', model: 'faggio', plate: 'RENT1107', image: Preview.img('faggio'), location: 'legion', locationLabel: 'Legion Square Rentals', category: 'Motorcycles', minutes: 30, durationLabel: '30 minutes', price: 100, deposit: 250, paid: 200, startedAt: now - 3400, expiresAt: now + 200, status: 'active', recharges: 1,
              extend: [{ id: '30m', minutes: 30, price: 100 }] },
        ];
    },
    accounts: () => [{ id: 'bank', balance: 48210 }, { id: 'cash', balance: 640 }],
    desk() {
        return { location: Preview.location(), accounts: Preview.accounts(), name: 'John Smith', rentals: [Preview.rentals()[0]], maxActive: 2,
            expiry: { mode: 'recharge', maxRecharges: 3, grace: 5 }, depositEnabled: true, damageDeduction: true, now: Math.floor(Date.now() / 1000) };
    },
    mine() {
        const now = Math.floor(Date.now() / 1000);
        return { rentals: Preview.rentals(), accounts: Preview.accounts(), name: 'John Smith', now, canExtend: true,
            history: [
                { id: 39, contract: 'CR-000039', label: 'Vapid Speedo', plate: 'RENT0934', status: 'returned', locationLabel: 'Legion Square Rentals', paid: 475, refund: 212, startedAt: now - 90000, endedAt: now - 86000 },
                { id: 31, contract: 'CR-000031', label: 'Dinka Blista', plate: 'RENT7720', status: 'repossessed', locationLabel: 'LSIA Car Hire', paid: 1050, refund: 0, startedAt: now - 260000, endedAt: now - 250000 },
            ] };
    },
    contract() {
        const now = Math.floor(Date.now() / 1000);
        return { id: 42, no: 'CR-000042', renter: 'John Smith', vehicle: 'Karin Sultan', model: 'sultan', plate: 'RENT4821', image: Preview.img('sultan'), category: 'Sport', location: 'Legion Square Rentals',
            durationLabel: '1 hour', price: 800, deposit: 750, paid: 800, recharges: 0, startedAt: now - 5, expiresAt: now + 3595, status: 'active',
            terms: { mode: 'recharge', maxRecharges: 3, grace: 5, anyLocation: true, damageDeduction: true }, now };
    },
    admin() {
        const now = Math.floor(Date.now() / 1000);
        const loc = Preview.location();
        const full = Object.assign({}, loc, {
            enabled: true, radius: 30, ped: { model: 'a_m_y_business_03', coords: { x: 109.97, y: -1088.61, z: 29.3, w: 345.64 } },
            blip: { enabled: true, sprite: 225, color: 5, scale: 0.75 }, spawns: [{ x: 111.42, y: -1081.24, z: 29.19, w: 340 }, { x: 115.8, y: -1082.6, z: 29.19, w: 340 }],
            categories: loc.categories.map(({ id, label, icon, license }) => ({ id, label, icon, license })),
            vehicles: loc.vehicles.map(({ model, label, category, type, prices }) => ({ model, label, category, type, prices: Object.fromEntries(Object.entries(prices).filter(([, p]) => p != null)), image: Preview.img(model) })),
        });
        return {
            name: 'John Smith', now,
            locations: [full, { id: 'lsia', label: 'LSIA Car Hire', enabled: false, radius: 40, ped: { model: 'a_f_y_business_02', coords: { x: -1034.9, y: -2733.6, z: 20.17, w: 330 } }, blip: { enabled: true, sprite: 225, color: 5, scale: 0.75 }, spawns: [], categories: [{ id: 'cars', label: 'Cars', icon: 'car' }], vehicles: [] }],
            activeAt: { legion: 2 },
            active: Preview.rentals().map((r, i) => Object.assign({}, r, { name: i ? 'Tasha Vale' : 'John Smith', online: !i })),
            history: Preview.mine().history.map((h) => Object.assign({ name: 'Marcus Reed', recharges: 0 }, h)),
            stats: { total: 184, revenue: 92540, today: 12, todayRevenue: 6875, repossessed: 3 },
            icons: ['car', 'sport', 'suv', 'van', 'truck', 'bike', 'scooter', 'cycle', 'boat', 'heli', 'plane', 'star'],
            licenses: ['bike', 'boat', 'driver', 'pilot', 'truck'],
            defaults: { ped: 'a_m_y_business_03', blip: { enabled: true, sprite: 225, color: 5, scale: 0.75 }, radius: 30, deposit: 250 },
            settings: [
                { key: 'Rentals.maxActive', group: 'rentals', type: 'int', min: 1, max: 10, value: 2, default: 1, changed: true },
                { key: 'Rentals.platePrefix', group: 'rentals', type: 'string', min: 1, max: 5, value: 'RENT', default: 'RENT' },
                { key: 'Rentals.warpIntoVehicle', group: 'rentals', type: 'bool', value: true, default: true },
                { key: 'Deposit.enabled', group: 'deposit', type: 'bool', value: true, default: true },
                { key: 'Deposit.amount', group: 'deposit', type: 'int', min: 0, max: 1000000, value: 250, default: 250 },
                { key: 'Expiry.mode', group: 'expiry', type: 'select', options: ['recharge', 'repossess'], value: 'recharge', default: 'recharge' },
                { key: 'Expiry.warnings', group: 'expiry', type: 'list', value: [10, 2], default: [10, 2] },
                { key: 'Expiry.maxRecharges', group: 'expiry', type: 'int', min: 0, max: 50, value: 3, default: 3 },
                { key: 'Return.anyLocation', group: 'return', type: 'bool', value: true, default: true },
            ],
        };
    },
};

if (!IS_GAME) {
    document.body.classList.add('preview');
    const params = new URLSearchParams(location.search);
    const base = { locale: window.PREVIEW_LOCALE || {}, theme: { primaryColor: '#2DD4BF', status: {} }, currency: '$', durations: [{ id: '30m', minutes: 30 }, { id: '1h', minutes: 60 }, { id: '3h', minutes: 180 }], accountsOrder: ['bank', 'cash'], admin: true, imagePath: 'https://docs.fivem.net/vehicles/%s.webp' };
    const m = params.get('mode') || 'desk';
    const data = m === 'admin' ? Preview.admin() : m === 'mine' ? Preview.mine() : Preview.desk();
    open(Object.assign({}, base, { mode: m, data }));
    if (m === 'desk' && params.get('page')) go(params.get('page'));
    if (m === 'admin' && params.get('page') === 'editor') { actions.editDesk({ dataset: { id: 'legion' } }); if (params.get('tab')) { S.ed.tab = params.get('tab'); rerender(); } }
    else if (m === 'admin' && params.get('page')) go(params.get('page'));
    if (params.get('contract')) showContract(Preview.contract(), true);
}
