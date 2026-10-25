--[[ ═══════════════════════════════════════════════════════════════════════
     LOCALE LOADER
     Language files live in locales/<code>.lua and register themselves in
     `Locales`. English is always loaded first, so a translation only needs
     the keys it changes. Add a language: copy locales/en.lua to
     locales/<code>.lua, translate, and set Config.Locale = '<code>'.
     ═══════════════════════════════════════════════════════════════════════ ]]

Locales = Locales or {}
Locale = { game = {}, ui = {}, settings = {} }

local function merge(into, from)
    for k, v in pairs(from or {}) do into[k] = v end
end

local base = Locales.en or {}
merge(Locale.game, base.game)
merge(Locale.ui, base.ui)
merge(Locale.settings, base.settings)

local chosen = Config.Locale and Locales[Config.Locale]
if chosen and Config.Locale ~= 'en' then
    merge(Locale.game, chosen.game)
    merge(Locale.ui, chosen.ui)
    merge(Locale.settings, chosen.settings)
end
