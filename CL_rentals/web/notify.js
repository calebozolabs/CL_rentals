/* ═══════════════════════════════════════════════════════════════════════
   CL NOTIFICATIONS
   One stack for every message the script shows: game messages from Lua
   ({ action: 'notify', data: { message, kind, title, duration, position } })
   and the menu's own messages (window.CLNotify.show). The same message shown
   again while it is still on screen is merged into it (×2, ×3 ...) instead of
   stacking duplicates, and an identical echo within 1.5 s is dropped. Style it in notify.css.
   ═══════════════════════════════════════════════════════════════════════ */

(() => {
    const KINDS = { success: 'success', error: 'error', warning: 'warning', warn: 'warning', info: 'info', inform: 'info', primary: 'info' };
    const ICONS = {
        success: '<path d="M3.5 8.5l3 3 6-7" />',
        error:   '<path d="M4.5 4.5l7 7M11.5 4.5l-7 7" />',
        warning: '<path d="M8 3.5v5.5" /><path d="M8 12.2v.1" />',
        info:    '<path d="M8 7v5" /><path d="M8 3.9v.1" />',
    };
    const MAX_VISIBLE = 5;
    const live = new Map();   // kind + message -> entry
    let stack, position = 'top-right', title = '';

    function mount() {
        if (!stack) {
            stack = document.createElement('div');
            stack.className = 'cln-stack';
            stack.dataset.pos = position;
            document.body.appendChild(stack);
        }
        return stack;
    }

    function remove(entry) {
        if (entry.gone) return;
        entry.gone = true;
        clearTimeout(entry.timer);
        live.delete(entry.key);
        entry.el.classList.add('out');
        setTimeout(() => entry.el.remove(), 260);
    }

    function arm(entry) {
        clearTimeout(entry.timer);
        entry.bar.style.animation = 'none';
        void entry.bar.offsetWidth;   // restart the countdown bar
        entry.bar.style.animation = '';
        entry.el.style.setProperty('--d', entry.duration + 'ms');
        entry.timer = setTimeout(() => remove(entry), entry.duration);
    }

    function show(opts) {
        if (typeof opts === 'string') opts = { message: opts };
        if (!opts || !opts.message) return;
        if (opts.position && opts.position !== position) {
            position = opts.position;
            mount().dataset.pos = position;
        }

        const kind = KINDS[opts.kind || opts.type] || 'info';
        const message = String(opts.message);
        const key = kind + '|' + message;
        const duration = Math.max(1500, Number(opts.duration) || 4200);

        const existing = live.get(key);
        // The same event can reach us twice (the menu and the server both report it): drop the echo
        if (existing && Date.now() - existing.shownAt < 1500) return;
        if (existing) {
            existing.shownAt = Date.now();
            existing.count += 1;
            existing.badge.textContent = '×' + existing.count;
            existing.badge.hidden = false;
            existing.duration = duration;
            existing.el.classList.remove('bump');
            void existing.el.offsetWidth;
            existing.el.classList.add('bump');
            arm(existing);
            return;
        }

        const el = document.createElement('div');
        el.className = 'cln ' + kind;
        el.innerHTML =
            '<div class="cln-ico"><svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">' + ICONS[kind] + '</svg></div>' +
            '<div class="cln-body"><div class="cln-title"></div><div class="cln-msg"></div></div>' +
            '<div class="cln-count" hidden></div><div class="cln-bar"></div>';
        el.querySelector('.cln-title').textContent = opts.title || title;
        el.querySelector('.cln-msg').textContent = message;

        const entry = { key, el, count: 1, duration, shownAt: Date.now(), badge: el.querySelector('.cln-count'), bar: el.querySelector('.cln-bar') };
        live.set(key, entry);
        mount().appendChild(el);
        arm(entry);

        // Keep the stack short: drop the oldest
        const shown = [...live.values()];
        if (shown.length > MAX_VISIBLE) remove(shown[0]);
    }

    window.CLNotify = {
        show,
        setTitle(t) { if (t) title = String(t); },
        setPosition(p) { if (p) { position = p; mount().dataset.pos = p; } },
    };

    window.addEventListener('message', (e) => {
        const d = e.data || {};
        if (d.action === 'notify' && d.data) show(d.data);
    });
})();
