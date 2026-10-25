/* ═══════════════════════════════════════════════════════════════════════
   Calebozolabs RENTALS — NUI core
   Helpers, icons, components, shell & router, modal, the rental contract,
   live countdowns and the message router. Desk / My rentals pages live in
   desk.js, the admin panel and desk editor in admin.js.
   ═══════════════════════════════════════════════════════════════════════ */

const IS_GAME = typeof window.GetParentResourceName === 'function';
const RESOURCE = IS_GAME ? window.GetParentResourceName() : 'CL_rentals';

const S = {
    open: false, mode: 'desk', page: null, L: {}, theme: {}, currency: '$', durations: [], accountsOrder: [],
    data: {}, skew: 0, sel: {}, ui: {}, keepScroll: false, admin: false,
};

const $ = (sel, root = document) => root.querySelector(sel);
const $$ = (sel, root = document) => [...root.querySelectorAll(sel)];
const arr = (v) => (Array.isArray(v) ? v : v && typeof v === 'object' ? Object.values(v) : []);
const esc = (v) => String(v ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const fmt = (n, d = 0) => Number(n || 0).toLocaleString('en-US', { minimumFractionDigits: d, maximumFractionDigits: d });
const money = (n) => `${Number(n) < 0 ? '-' : ''}${S.currency}${fmt(Math.abs(Math.round(Number(n) || 0)))}`;
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));

function t(key, ...args) {
    let str = S.L[key] ?? key;
    args.forEach((a) => { str = str.replace('%s', a); });
    return str;
}

function hexRgb(hex) {
    const h = String(hex || '#2DD4BF').replace('#', '');
    const full = h.length === 3 ? h.split('').map((c) => c + c).join('') : h.slice(0, 6);
    const n = parseInt(full, 16);
    return `${(n >> 16) & 255}, ${(n >> 8) & 255}, ${n & 255}`;
}

function initials(name) {
    return String(name || '?').trim().split(/\s+/).slice(0, 2).map((p) => p[0] || '').join('').toUpperCase() || '?';
}

/** Server time (seconds), corrected for the difference with this machine's clock */
function nowSec() { return Math.floor(Date.now() / 1000) + S.skew; }
function syncClock(now) { if (now) S.skew = Number(now) - Math.floor(Date.now() / 1000); }

function durationLabel(minutes) {
    const m = Math.floor(Number(minutes) || 0);
    if (m < 60) return t('minutes_n', m);
    const h = Math.floor(m / 60), r = m % 60;
    if (r) return t('hours_minutes', h, r);
    return h === 1 ? t('hour_1') : t('hours_n', h);
}

function shortDuration(minutes) {
    const m = Math.floor(Number(minutes) || 0);
    if (m < 60) return t('short_min', m);
    const h = m / 60;
    return t('short_hour', Number.isInteger(h) ? h : fmt(h, 1));
}

function countdown(seconds) {
    const s = Math.max(0, Math.floor(seconds || 0));
    const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), sec = s % 60;
    if (h > 0) return `${h}:${String(m).padStart(2, '0')}:${String(sec).padStart(2, '0')}`;
    return `${m}:${String(sec).padStart(2, '0')}`;
}

function dateStr(ts) {
    if (!ts) return '—';
    const d = new Date(Number(ts) * 1000);
    return `${d.toLocaleDateString('en-GB', { day: '2-digit', month: 'short' })} · ${d.toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit' })}`;
}

function ago(ts) {
    if (!ts) return '—';
    const s = nowSec() - Number(ts);
    if (s < 60) return t('just_now');
    if (s < 3600) return t('min_ago', Math.floor(s / 60));
    if (s < 86400) return t('hours_ago', Math.floor(s / 3600));
    return t('days_ago', Math.floor(s / 86400));
}

async function nui(name, data = {}) {
    if (!IS_GAME) return window.Preview ? window.Preview.handle(name, data) : null;
    try {
        const res = await fetch(`https://${RESOURCE}/${name}`, {
            method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(data),
        });
        return await res.json();
    } catch (e) {
        return null;
    }
}

/** Server action through the whitelisted `call` NUI callback → { ok, message, data } */
async function call(name, ...args) {
    const res = await nui('call', { name, args, argc: args.length });
    return res || { ok: false, message: t('failed') };
}

function toast(message, kind = 'info') {
    if (message) window.CLNotify.show({ message, kind });
}

async function act(btn, name, ...args) {
    if (btn) btn.classList.add('loading');
    try {
        const res = await call(name, ...args);
        if (res.message) toast(res.message, res.ok ? 'success' : 'error');
        else if (!res.ok) toast(t('failed'), 'error');
        return res;
    } finally {
        if (btn) btn.classList.remove('loading');
    }
}

/* ═══════════════════════════════════════════════════════════════════════
   ICONS
   ═══════════════════════════════════════════════════════════════════════ */

const svg = (d, size = 18, sw = 1.6) =>
    `<svg width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="${sw}" stroke-linecap="round" stroke-linejoin="round">${d}</svg>`;

const I = {
    car: (s) => svg('<path d="M4 16.5V12l2-5h12l2 5v4.5"/><path d="M3 12h18v4.5H3z"/><circle cx="7.5" cy="16.5" r="1.8"/><circle cx="16.5" cy="16.5" r="1.8"/><path d="M7 9.5h10"/>', s),
    sport: (s) => svg('<path d="M2.5 15.5l2-4 5-2.5h5.5l4 3 2.5.5v3"/><path d="M2.5 15.5h19"/><circle cx="7" cy="16" r="1.8"/><circle cx="17" cy="16" r="1.8"/><path d="M10 9l1.5 3h6"/>', s),
    suv: (s) => svg('<path d="M3 16.5V10l2.5-4h10l3 4H21v6.5"/><path d="M3 10.5h18"/><circle cx="7.5" cy="16.5" r="1.8"/><circle cx="16.5" cy="16.5" r="1.8"/><path d="M11 6v4.5"/>', s),
    van: (s) => svg('<path d="M2.5 16V7.5A1.5 1.5 0 0 1 4 6h10v10"/><path d="M14 9h4l3.5 4v3H14"/><circle cx="6.5" cy="17" r="1.8"/><circle cx="17.5" cy="17" r="1.8"/><path d="M5 9.5h6"/>', s),
    truck: (s) => svg('<path d="M2 16V6h11v10"/><path d="M13 9h4.5l3 3.5V16H13"/><circle cx="6" cy="17" r="1.8"/><circle cx="16.5" cy="17" r="1.8"/>', s),
    bike: (s) => svg('<circle cx="5.5" cy="16" r="3.5"/><circle cx="18.5" cy="16" r="3.5"/><path d="M5.5 16l4-6h5l4 6M9.5 10L8 7H6M14.5 10l1.5-3h2.5"/>', s),
    scooter: (s) => svg('<circle cx="6" cy="17" r="2.5"/><circle cx="18" cy="17" r="2.5"/><path d="M6 17h7l2-8h3M15 9l3 8M9 13h5"/>', s),
    cycle: (s) => svg('<circle cx="6" cy="16" r="3.5"/><circle cx="18" cy="16" r="3.5"/><path d="M6 16l4-8h5l3 8M10 8l2 8h-6M14.5 5H17"/>', s),
    boat: (s) => svg('<path d="M3 15l2 4h14l2-4z"/><path d="M6 15V9h8l3 6"/><path d="M10 9V5"/><path d="M2 21c2 0 2-1 4-1s2 1 4 1 2-1 4-1 2 1 4 1 2-1 4-1"/>', s),
    heli: (s) => svg('<path d="M3 5h16M11 5v3"/><path d="M5 14a6 5 0 0 1 6-5h3a5 5 0 0 1 0 10H9"/><path d="M19 13h2v-3M9 19l-1 2M15 19l1 2"/>', s),
    plane: (s) => svg('<path d="M21 15.5l-8-4V5a1.5 1.5 0 0 0-3 0v6.5l-8 4V17l8-2.5V19l-2 1.5V22l3.5-1 3.5 1v-1.5L13 19v-4.5l8 2.5z"/>', s),
    star: (s) => svg('<path d="M12 3.5l2.6 5.3 5.9.9-4.3 4.1 1 5.8L12 16.9l-5.2 2.7 1-5.8L3.5 9.7l5.9-.9z"/>', s),
    key: (s) => svg('<circle cx="8" cy="14" r="4.5"/><path d="M11.2 10.8L20 2M16.5 5.5l2.5 2.5M14 8l2 2"/>', s),
    grid: (s) => svg('<rect x="3.5" y="3.5" width="7" height="7" rx="1.5"/><rect x="13.5" y="3.5" width="7" height="7" rx="1.5"/><rect x="3.5" y="13.5" width="7" height="7" rx="1.5"/><rect x="13.5" y="13.5" width="7" height="7" rx="1.5"/>', s),
    clock: (s) => svg('<circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2"/>', s),
    doc: (s) => svg('<path d="M6 3h8l4 4v14H6z"/><path d="M14 3v4h4M9 12h6M9 16h6"/>', s),
    contract: (s) => svg('<path d="M6 3h8l4 4v14H6z"/><path d="M14 3v4h4M9 10h5M9 13.5h6"/><path d="M9 18c1-1.5 2-1.5 2.5 0s1.5 1 3-.5"/>', s),
    pin: (s) => svg('<path d="M12 21s-6.5-5.6-6.5-11a6.5 6.5 0 0 1 13 0c0 5.4-6.5 11-6.5 11z"/><circle cx="12" cy="10" r="2.2"/>', s),
    cash: (s) => svg('<rect x="3" y="6.5" width="18" height="11" rx="2"/><circle cx="12" cy="12" r="2.5"/><path d="M6.5 9.5v5M17.5 9.5v5"/>', s),
    bank: (s) => svg('<path d="M3 9.5L12 4l9 5.5"/><path d="M5 10v7M9.5 10v7M14.5 10v7M19 10v7"/><path d="M3 20h18"/>', s),
    user: (s) => svg('<circle cx="12" cy="8" r="3.6"/><path d="M5 20a7 7 0 0 1 14 0"/>', s),
    users: (s) => svg('<circle cx="9" cy="8" r="3.2"/><path d="M3.5 19a5.5 5.5 0 0 1 11 0"/><circle cx="17" cy="9" r="2.4"/><path d="M16 14.2a4.5 4.5 0 0 1 5 4.8"/>', s),
    gear: (s) => svg('<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.6 1.6 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.6 1.6 0 0 0-2.7 1.1V21a2 2 0 1 1-4 0v-.1a1.6 1.6 0 0 0-2.7-1.1l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.6 1.6 0 0 0-1.1-2.7H3a2 2 0 1 1 0-4h.1a1.6 1.6 0 0 0 1.1-2.7l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.6 1.6 0 0 0 2.7-1.1V3a2 2 0 1 1 4 0v.1a1.6 1.6 0 0 0 2.7 1.1l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.6 1.6 0 0 0 1.1 2.7H21a2 2 0 1 1 0 4h-.1a1.6 1.6 0 0 0-1.5 1.1z"/>', s, 1.4),
    store: (s) => svg('<path d="M4 9.5V20h16V9.5"/><path d="M3 5h18l-1.5 4.5a2.5 2.5 0 0 1-4.5 0 2.5 2.5 0 0 1-5 0 2.5 2.5 0 0 1-4.5 0z"/><path d="M10 20v-5h4v5"/>', s),
    live: (s) => svg('<circle cx="12" cy="12" r="2.5"/><path d="M7.8 7.8a6 6 0 0 0 0 8.4M16.2 7.8a6 6 0 0 1 0 8.4M4.9 4.9a10 10 0 0 0 0 14.2M19.1 4.9a10 10 0 0 1 0 14.2"/>', s),
    history: (s) => svg('<path d="M3.5 12a8.5 8.5 0 1 0 2.5-6"/><path d="M3 4v4h4"/><path d="M12 8v4.5l3 1.5"/>', s),
    check: (s) => svg('<path d="M5 12.5l4.5 4.5L19 7.5"/>', s, 2.2),
    x: (s) => svg('<path d="M6 6l12 12M18 6L6 18"/>', s, 2),
    plus: (s) => svg('<path d="M12 5v14M5 12h14"/>', s, 2),
    edit: (s) => svg('<path d="M4 20h4L19 9l-4-4L4 16z"/><path d="M13.5 6.5l4 4"/>', s),
    trash: (s) => svg('<path d="M4 7h16M10 11v6M14 11v6"/><path d="M6 7l1 13h10l1-13M9 7V4h6v3"/>', s),
    target: (s) => svg('<circle cx="12" cy="12" r="7.5"/><path d="M12 2v4M12 18v4M2 12h4M18 12h4"/><circle cx="12" cy="12" r="1.5"/>', s),
    here: (s) => svg('<circle cx="12" cy="12" r="3"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3"/>', s),
    tp: (s) => svg('<path d="M12 21s-6.5-5.6-6.5-11a6.5 6.5 0 0 1 13 0c0 5.4-6.5 11-6.5 11z"/><path d="M12 7v6M9 10l3-3 3 3"/>', s),
    arrowL: (s) => svg('<path d="M19 12H5M11 6l-6 6 6 6"/>', s),
    up: (s) => svg('<path d="M12 19V5M6 11l6-6 6 6"/>', s),
    down: (s) => svg('<path d="M12 5v14M6 13l6 6 6-6"/>', s),
    search: (s) => svg('<circle cx="11" cy="11" r="6.5"/><path d="M20 20l-4.2-4.2"/>', s),
    alert: (s) => svg('<path d="M12 3l9.5 17h-19z"/><path d="M12 10v4.5M12 17.5v.1"/>', s),
    info: (s) => svg('<circle cx="12" cy="12" r="8.5"/><path d="M12 11v5.5M12 7.8v.1"/>', s),
    refresh: (s) => svg('<path d="M20 11a8 8 0 0 0-14.9-3.5M4 4v4h4"/><path d="M4 13a8 8 0 0 0 14.9 3.5M20 20v-4h-4"/>', s),
    plusTime: (s) => svg('<circle cx="11" cy="13" r="7.5"/><path d="M11 9.5V13l2 1.5M19 3v4M17 5h4"/>', s),
    shield: (s) => svg('<path d="M12 3l7 3v5c0 4.5-3 8-7 10-4-2-7-5.5-7-10V6z"/><path d="M9 12l2 2 4-4"/>', s),
    id: (s) => svg('<rect x="3" y="5" width="18" height="14" rx="2"/><circle cx="8.5" cy="11" r="2"/><path d="M5.5 16a3 3 0 0 1 6 0M14 10h4M14 13.5h3"/>', s),
};

const CAT_ICONS = { car: I.car, sport: I.sport, suv: I.suv, van: I.van, truck: I.truck, bike: I.bike, scooter: I.scooter, cycle: I.cycle, boat: I.boat, heli: I.heli, plane: I.plane, star: I.star };
const catIcon = (id, size) => (CAT_ICONS[id] || I.car)(size);
const accIcon = (id, size) => (id === 'cash' ? I.cash : I.bank)(size);
const HEX_POINTS = '26,2.5 48.5,15.25 48.5,42.75 26,55.5 3.5,42.75 3.5,15.25';

function hexSvg(fill, uid = 'h') {
    return `<svg viewBox="0 0 52 58" width="100%" height="100%" fill="none">
        <defs><filter id="${uid}f" x="-30%" y="-30%" width="160%" height="160%"><feDropShadow dx="0" dy="4" stdDeviation="4" flood-color="${fill}" flood-opacity="0.35"/></filter></defs>
        <polygon points="${HEX_POINTS}" fill="${fill}" stroke="${fill}" stroke-width="3" stroke-linejoin="round" filter="url(#${uid}f)"/>
        <polygon points="26,9 43,18.8 43,39.2 26,49 9,39.2 9,18.8" fill="#121212" fill-opacity="0.82" stroke="#121212" stroke-opacity="0.6" stroke-linejoin="round"/>
    </svg>`;
}

function logoSvg(icon, uid = 'logo', size = 22) {
    const a = S.theme.primaryColor || '#2DD4BF';
    return `<div style="position:relative;width:100%;height:100%">${hexSvg(a, uid)}
        <div style="position:absolute;inset:0;display:flex;align-items:center;justify-content:center;color:${a};padding-top:2px">${(icon || I.key)(size)}</div></div>`;
}

/* ═══════════════════════════════════════════════════════════════════════
   COMPONENTS
   ═══════════════════════════════════════════════════════════════════════ */

const STATUS_COLORS = { active: '#2DD4BF', overdue: '#FFB347', returned: '#4ADE80', repossessed: '#F22933', lost: '#F22933', ended: '#9CA3AF', restart: '#9CA3AF' };
function statusColor(status) { return (S.theme.status || {})[status] || STATUS_COLORS[status] || S.theme.primaryColor; }
function statusPill(status) {
    const c = statusColor(status);
    return `<span class="status" style="--sc:${c};--sc-rgb:${hexRgb(c)}">${esc(t('st_' + status))}</span>`;
}

function plate(p, lg) { return `<span class="plate ${lg ? 'lg' : ''}">${esc(p || '—')}</span>`; }

/** Vehicle picture with an icon behind it for models that have no picture */
function thumb(image, cls = '', icon = 'car', corner = '') {
    return `<div class="thumb ${cls}">${image ? `<img src="${esc(image)}" onerror="this.remove()">` : ''}<div class="ph">${catIcon(icon, cls.includes('xs') ? 20 : 34)}</div>${corner}</div>`;
}

function bar(p, opts = {}) {
    const v = clamp(Number(p) || 0, 0, 100);
    return `<div class="bar ${opts.cls || ''}"><div class="fill" style="width:${v}%;${opts.rgb ? `--bc-rgb:${opts.rgb}` : ''}"></div></div>`;
}

function empty(icon, text, extra = '') { return `<div class="empty">${icon(30)}<span>${esc(text)}</span>${extra}</div>`; }

function toggle(id, on, label) {
    return `<label class="toggle ${on ? 'on' : ''}" data-toggle="${esc(id)}"><span class="sw"></span>${label ? esc(label) : ''}</label>`;
}

/** Remaining-time widget; updated every second by the ticker (data-exp) */
function timerBox(r) {
    return `<div class="timer" data-exp="${r.expiresAt}" data-len="${(r.minutes || 0) * 60}">
        <div class="v">${countdown(r.expiresAt - nowSec())}</div><div class="l">${esc(t('time_left'))}</div>${bar(100, { cls: 'thin' })}</div>`;
}

function tickTimers() {
    const now = nowSec();
    $$('[data-exp]').forEach((el) => {
        const left = Number(el.dataset.exp) - now;
        const len = Number(el.dataset.len) || 1;
        const v = el.querySelector('.v') || el;
        v.textContent = left > 0 ? countdown(left) : t('overdue');
        v.classList.toggle('warn', left > 0 && left <= 600);
        v.classList.toggle('bad', left <= 0);
        const fill = el.querySelector('.fill');
        if (fill) {
            fill.style.width = `${clamp((left / len) * 100, 0, 100)}%`;
            fill.style.setProperty('--bc-rgb', hexRgb(left <= 600 ? (S.theme.warning || '#FFB347') : (S.theme.primaryColor || '#2DD4BF')));
        }
    });
}
setInterval(tickTimers, 1000);

/* ═══════════════════════════════════════════════════════════════════════
   SHELL & ROUTER
   ═══════════════════════════════════════════════════════════════════════ */

const PAGES = {};    // filled by desk.js / admin.js: id -> { icon, label, render, after, badge }
const MODES = {};    // mode -> { nav(): [[ids]], title(), subtitle(), navLabel(), stats(), first(), logo }

function applyTheme() {
    const accent = S.theme.primaryColor || '#2DD4BF';
    const root = document.documentElement.style;
    root.setProperty('--accent', accent);
    root.setProperty('--accent-rgb', hexRgb(accent));
    ['success', 'danger', 'warning', 'info'].forEach((k) => { if (S.theme[k]) root.setProperty(`--${k}`, S.theme[k]); });
}

function mode() { return MODES[S.mode] || MODES.desk; }

function renderShell() {
    const m = mode();
    $('#logo').innerHTML = logoSvg(m.logo || I.key);
    $('#title').textContent = m.title();
    $('#subtitle').innerHTML = m.subtitle();
    $('#navLabel').textContent = m.navLabel();
    $('#headerStats').innerHTML = m.stats ? m.stats() : '';
    renderNav();
    renderProfile();
}

function renderNav() {
    let i = 0;
    const groups = mode().nav();
    $('#nav').innerHTML = groups.map((group, gi) => {
        const items = group.filter((id) => PAGES[id] || id.startsWith('cat:')).map((id) => {
            const p = pageOf(id);
            const badge = p.badge ? p.badge() : '';
            const active = S.page === id || (p.parent && S.page === p.parent);
            return `<div class="nav-item ${active ? 'active' : ''}" data-nav="${esc(id)}" style="animation-delay:${0.2 + i++ * 0.035}s">
                <div class="icon">${p.icon(17)}</div><div class="label">${esc(p.label())}</div>${badge}</div>`;
        }).join('');
        return items + (gi < groups.length - 1 && items ? '<div class="nav-sep"></div>' : '');
    }).join('');
}

/** Desk categories share one page with a different filter */
function pageOf(id) {
    if (id && id.startsWith('cat:')) return PAGES.category(id.slice(4));
    return PAGES[id] || PAGES[mode().first()];
}

function renderProfile() {
    const name = S.data.name || '—';
    $('#profileCard').innerHTML = `<div class="avatar">${esc(initials(name))}</div>
        <div class="who"><div class="role">${esc(t(S.mode === 'admin' ? 'role_admin' : 'role_renter'))}</div>
            <div class="name">${esc(name)}</div></div>`;
}

function render() {
    const page = pageOf(S.page);
    const scroll = $('#content .scroll');
    const top = scroll ? scroll.scrollTop : 0;
    $('#content').innerHTML = `<div class="page ${S.keepScroll ? 'static' : ''}">${page.render()}</div>`;
    if (S.keepScroll) { const s = $('#content .scroll'); if (s) s.scrollTop = top; S.keepScroll = false; }
    if (page.after) page.after();
    tickTimers();
}

function rerender() { S.keepScroll = true; renderShell(); render(); }

function go(id) {
    S.page = id;
    renderNav();
    render();
    const page = pageOf(id);
    if (page.enter) page.enter();
}

/* ═══════════════════════════════════════════════════════════════════════
   MODAL
   ═══════════════════════════════════════════════════════════════════════ */

let modalConfirm = null;

/** opts: { title, body, confirm, confirmClass, wide, cancel, noFoot, onConfirm(box) -> Promise<boolean> (true closes), onRender(box) } */
function modal(opts) {
    modalConfirm = opts.onConfirm || null;
    const m = $('#modal');
    m.innerHTML = `<div class="mbox ${opts.wide ? 'wide' : ''}"><div class="accentline"></div>
        <div class="mhead"><div class="t">${esc(opts.title)}</div><button class="x" data-act="modalClose">${I.x(12)}</button></div>
        <div class="mbody">${opts.body}</div>
        ${opts.noFoot ? '' : `<div class="mfoot"><button class="btn ghost" data-act="modalClose">${esc(opts.cancel || t('cancel'))}</button>
            ${opts.confirm ? `<button class="btn ${opts.confirmClass || 'primary'}" data-act="modalConfirm">${esc(opts.confirm)}</button>` : ''}</div>`}
    </div>`;
    m.classList.remove('hidden');
    if (opts.onRender) opts.onRender(m);
    const first = m.querySelector('input:not([type=hidden]):not([type=range])');
    if (first) setTimeout(() => first.focus(), 50);
}

function closeModal() {
    $('#modal').classList.add('hidden');
    $('#modal').innerHTML = '';
    modalConfirm = null;
}

function confirmBox(title, text, confirm, cls, onYes) {
    modal({ title, body: `<div>${text}</div>`, confirm, confirmClass: cls || 'primary', onConfirm: async () => { await onYes(); return true; } });
}

/* ═══════════════════════════════════════════════════════════════════════
   RENTAL CONTRACT
   ═══════════════════════════════════════════════════════════════════════ */

let docOpen = false;
let docFromMenu = false;

function signature(name) {
    return `<svg viewBox="0 0 320 50" preserveAspectRatio="xMinYMax meet"><text x="0" y="40">${esc(name)}</text></svg>`;
}

function contractTerms(c) {
    const tm = c.terms || {};
    const lines = [t('term_return', c.durationLabel)];
    if (tm.mode === 'repossess') lines.push(t('term_repossess', tm.grace));
    else lines.push(tm.maxRecharges > 0 ? t('term_recharge_max', money(c.price), c.durationLabel, tm.maxRecharges) : t('term_recharge', money(c.price), c.durationLabel));
    if (c.deposit > 0) lines.push(tm.damageDeduction ? t('term_deposit_damage', money(c.deposit)) : t('term_deposit', money(c.deposit)));
    lines.push(t(tm.anyLocation ? 'term_any_desk' : 'term_same_desk', c.location));
    return `<ul class="terms"><div class="h">${esc(t('terms'))}</div>${lines.map((l) => `<li>${esc(l)}</li>`).join('')}</ul>`;
}

function contractHtml(c) {
    const closed = !['active', 'overdue'].includes(c.status);
    const stampColor = statusColor(c.status);
    const ret = closed && c.status === 'returned' ? `
        <div class="doc-grid">
            <div class="cell"><div class="k">${esc(t('c_returned'))}</div><div class="v">${esc(dateStr(c.endedAt))}</div></div>
            <div class="cell"><div class="k">${esc(t('c_damage'))}</div><div class="v">${fmt(c.damage)}%</div></div>
            <div class="cell"><div class="k">${esc(t('c_deposit_kept'))}</div><div class="v ${c.deposit - c.refund > 0 ? 'bad-t' : ''}">${money(c.deposit - (c.refund || 0))}</div></div>
            <div class="cell"><div class="k">${esc(t('c_refunded'))}</div><div class="v good-t">${money(c.refund)}</div></div>
        </div>` : '';
    return `<div class="doc contract"><div class="accentline"></div>
        <div class="stamp" style="--sc:${stampColor}">${esc(t('st_' + c.status))}</div>
        <div class="doc-head"><div class="brandline"><div class="logo">${logoSvg(I.key, 'doclogo', 17)}</div>
            <div><div class="kind">${esc(t('contract_title'))}</div><div class="no">${esc(c.no)} · ${esc(c.location)}</div></div></div></div>
        <div class="doc-body">
            <div class="doc-hero">${thumb(c.image, '', 'car')}
                <div><div class="vn">${esc(c.vehicle)}</div><div class="vs">${plate(c.plate, true)}${c.category ? `<span class="chip sm">${esc(c.category)}</span>` : ''}</div></div></div>
            <div class="doc-grid">
                <div class="cell span"><div class="k">${esc(t('c_renter'))}</div><div class="v big">${esc(c.renter)}</div></div>
                <div class="cell"><div class="k">${esc(t('c_vehicle'))}</div><div class="v">${esc(c.vehicle)}</div></div>
                <div class="cell"><div class="k">${esc(t('c_plate'))}</div><div class="v mono">${esc(c.plate)}</div></div>
                <div class="cell"><div class="k">${esc(t('c_period'))}</div><div class="v">${esc(c.durationLabel)}</div></div>
                <div class="cell"><div class="k">${esc(t('c_desk'))}</div><div class="v">${esc(c.location)}</div></div>
                <div class="cell"><div class="k">${esc(t('c_start'))}</div><div class="v">${esc(dateStr(c.startedAt))}</div></div>
                <div class="cell"><div class="k">${esc(t(closed ? 'c_was_due' : 'c_due'))}</div><div class="v">${esc(dateStr(c.expiresAt))}${closed ? '' : ` <span class="dim" data-exp="${c.expiresAt}" data-len="1">${countdown(c.expiresAt - nowSec())}</span>`}</div></div>
                <div class="cell"><div class="k">${esc(t('c_price'))}</div><div class="v">${money(c.price)}</div></div>
                <div class="cell"><div class="k">${esc(t('c_deposit'))}</div><div class="v">${c.deposit > 0 ? money(c.deposit) : esc(t('none'))}</div></div>
                ${c.recharges > 0 ? `<div class="cell span"><div class="k">${esc(t('c_renewals'))}</div><div class="v warn-t">${esc(t('c_renewals_v', c.recharges, money(c.paid)))}</div></div>` : ''}
            </div>
            ${ret}
            ${contractTerms(c)}
            <div class="signs">
                <div class="sign"><div style="flex:1"><div class="line">${signature(c.renter)}</div><div class="cap">${esc(t('c_sign_renter'))}</div></div></div>
                <div class="sign"><div style="flex:1"><div class="line">${signature(c.location)}</div><div class="cap">${esc(t('c_sign_agent'))}</div></div></div>
            </div>
        </div>
        <div class="doc-foot"><button class="btn primary" data-act="docClose">${esc(t('close'))}</button></div></div>`;
}

/** fromMenu: opened over the menu (keeps the menu open behind it) */
function showContract(c, fromMenu) {
    syncClock(c.now);
    docOpen = true;
    docFromMenu = !!fromMenu;
    $('#doc').innerHTML = contractHtml(c);
    $('#doc').classList.remove('hidden');
    tickTimers();
}

function hideContract() {
    if (!docOpen) return;
    docOpen = false;
    $('#doc').classList.add('hidden');
    $('#doc').innerHTML = '';
    if (!docFromMenu) nui('docClose');
}

/* ═══════════════════════════════════════════════════════════════════════
   ACTIONS & EVENT DELEGATION
   ═══════════════════════════════════════════════════════════════════════ */

const actions = {
    modalClose() { closeModal(); },
    async modalConfirm(el) {
        if (!modalConfirm) return closeModal();
        el.classList.add('loading');
        const box = $('#modal');
        try { if (await modalConfirm(box)) closeModal(); } finally { el.classList.remove('loading'); }
    },
    docClose() { hideContract(); },
    goto(el) { go(el.dataset.page); },
    seg(el) { S.ui[el.dataset.group] = el.dataset.value; rerender(); },
};
const toggles = {};   // data-toggle id -> fn(on, el)
const changes = {};   // data-change id -> fn(el)
const inputs = {};    // data-input id -> fn(el)

document.addEventListener('click', (e) => {
    const nav = e.target.closest('[data-nav]');
    if (nav) return go(nav.dataset.nav);
    const tg = e.target.closest('[data-toggle]');
    if (tg) {
        e.preventDefault();
        tg.classList.toggle('on');
        const fn = toggles[tg.dataset.toggle.split(':')[0]];
        if (fn) fn(tg.classList.contains('on'), tg);
        return;
    }
    const el = e.target.closest('[data-act]');
    if (el && actions[el.dataset.act]) { e.preventDefault(); actions[el.dataset.act](el, e); }
});

document.addEventListener('input', (e) => {
    const id = e.target.dataset && e.target.dataset.input;
    if (id && inputs[id]) inputs[id](e.target);
});

document.addEventListener('change', (e) => {
    const id = e.target.dataset && e.target.dataset.change;
    if (id && changes[id]) changes[id](e.target);
});

function rerenderKeepFocus(el) {
    const key = el && el.dataset && el.dataset.focus;
    const caret = el ? el.selectionStart : null;
    rerender();
    if (!key) return;
    const again = document.querySelector(`[data-focus="${key}"]`);
    if (again) { again.focus(); if (caret != null && again.setSelectionRange) try { again.setSelectionRange(caret, caret); } catch (e) { /* number input */ } }
}

/* ─── Open / close ─────────────────────────────────────────────────── */

function adopt(payload) {
    if (!payload) return;
    if (payload.locale) S.L = payload.locale;
    if (payload.theme) { S.theme = payload.theme; applyTheme(); }
    if (payload.currency) S.currency = payload.currency;
    if (payload.durations) S.durations = arr(payload.durations);
    if (payload.accountsOrder) S.accountsOrder = arr(payload.accountsOrder);
    if (payload.admin !== undefined) S.admin = !!payload.admin;
    if (payload.imagePath !== undefined) S.imagePath = payload.imagePath || null;
    window.CLNotify.setTitle(t('notify_title'));
}

function open(payload) {
    adopt(payload);
    S.mode = payload.mode || 'desk';
    S.data = payload.data || {};
    syncClock(S.data.now);
    S.sel = {};
    S.ui = {};
    S.open = true;
    closeModal();
    const menu = $('#menu');
    menu.classList.remove('hidden', 'closing');
    const frame = menu.querySelector('.frame');
    frame.style.animation = 'none'; void frame.offsetWidth; frame.style.animation = '';
    const m = mode();
    if (m.init) m.init();
    S.page = m.first();
    renderShell();
    render();
    const page = pageOf(S.page);
    if (page.enter) page.enter();
}

/** keepFocus: a contract is shown right after (renting) */
function close(silent, keepFocus) {
    if (!S.open) return;
    S.open = false;
    closeModal();
    const menu = $('#menu');
    menu.classList.add('closing');
    setTimeout(() => { if (!S.open) menu.classList.add('hidden'); }, 240);
    if (!silent) nui('close', { keepFocus: !!keepFocus });
}

$('#closeBtn').addEventListener('click', () => {
    if (MODES[S.mode] && MODES[S.mode].beforeClose && !MODES[S.mode].beforeClose()) return;
    close();
});

document.addEventListener('keydown', (e) => {
    if (e.key === 'Enter' && !$('#modal').classList.contains('hidden') && e.target.closest('#modal') && e.target.tagName !== 'TEXTAREA') {
        return actions.modalConfirm($('[data-act=modalConfirm]'));
    }
    if (e.key !== 'Escape') return;
    if (docOpen) return hideContract();
    if (!$('#modal').classList.contains('hidden')) return closeModal();
    if (S.open) {
        if (MODES[S.mode] && MODES[S.mode].beforeClose && !MODES[S.mode].beforeClose()) return;
        close();
    }
});

/* ─── Messages from Lua ────────────────────────────────────────────── */

window.addEventListener('message', (e) => {
    const { action, data } = e.data || {};
    switch (action) {
        case 'init': adopt(data); break;
        case 'open': open(data); break;
        case 'close': close(true); break;
        case 'contract': adopt(data); showContract(data.contract, false); break;
        case 'hide': document.body.classList.toggle('placing', !!data); break;
        case 'rentals':
            if (!S.open) break;
            syncClock(data.now);
            S.data.rentals = arr(data.rentals);
            if (mode().onRentals) mode().onRentals();
            break;
    }
});
