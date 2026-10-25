Utils = {}

local RESOURCE = GetCurrentResourceName()

function Utils.debug(...)
    if Config.Debug then
        local parts = {}
        for i = 1, select('#', ...) do parts[i] = tostring(select(i, ...)) end
        print(('^5[%s]^7 %s'):format(RESOURCE, table.concat(parts, ' ')))
    end
end

function Utils.t(key, ...)
    local str = Locale.game[key] or key
    if select('#', ...) > 0 then
        local ok, out = pcall(string.format, str, ...)
        return ok and out or str
    end
    return str
end

function Utils.trim(value)
    return (tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', ''))
end

function Utils.plate(value)
    return Utils.trim(value):upper()
end

function Utils.clamp(v, lo, hi)
    v = tonumber(v) or lo
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

function Utils.round(v, step)
    step = step or 1
    return math.floor((tonumber(v) or 0) / step + 0.5) * step
end

function Utils.contains(list, value)
    if not list then return false end
    for i = 1, #list do
        if list[i] == value then return true end
    end
    return false
end

function Utils.copy(value)
    if type(value) ~= 'table' then return value end
    local out = {}
    for k, v in pairs(value) do out[k] = Utils.copy(v) end
    return out
end

function Utils.count(t)
    local n = 0
    for _ in pairs(t or {}) do n = n + 1 end
    return n
end

function Utils.toVec3(value)
    if not value then return nil end
    local t = type(value)
    if t == 'vector3' then return value end
    if t == 'vector4' then return vec3(value.x, value.y, value.z) end
    if t == 'table' then return vec3(tonumber(value.x) or 0.0, tonumber(value.y) or 0.0, tonumber(value.z) or 0.0) end
end

--- vec -> plain table (JSON / NUI)
function Utils.fromVec(v)
    if not v then return nil end
    local r = function(n) return math.floor((n or 0.0) * 100 + 0.5) / 100 end
    return { x = r(v.x), y = r(v.y), z = r(v.z), w = v.w and r(v.w) or nil }
end

function Utils.formatMoney(amount)
    local n = math.floor(tonumber(amount) or 0)
    local neg = n < 0
    local formatted = tostring(math.abs(n))
    local k
    repeat
        formatted, k = formatted:gsub('^(%d+)(%d%d%d)', '%1,%2')
    until k == 0
    return (neg and '-' or '') .. Config.CurrencySymbol .. formatted
end

--- 30 → "30 minutes", 60 → "1 hour", 180 → "3 hours", 90 → "1 h 30 min"
function Utils.durationLabel(minutes)
    minutes = math.floor(tonumber(minutes) or 0)
    if minutes < 60 then return Utils.t('minutes_n', minutes) end
    local h, m = math.floor(minutes / 60), minutes % 60
    if m > 0 then return Utils.t('hours_minutes', h, m) end
    return h == 1 and Utils.t('hour_1') or Utils.t('hours_n', h)
end

function Utils.duration(id)
    for _, d in ipairs(Config.Durations) do
        if d.id == id then return d end
    end
end

--- Contract number shown on the paper: CR-000042
function Utils.contractNo(id)
    return ('CR-%06d'):format(tonumber(id) or 0)
end

--- oxmysql can return TINYINT(1) as true / false or 1 / 0.
function Utils.bool(v)
    return v == true or v == 1 or v == '1'
end

--[[ ─── Config paths (in-game settings editor) ─────────────────────────────
     'Expiry.mode' → Config.Expiry.mode. ]]

function Utils.cfgGet(path)
    local node = Config
    for p in path:gmatch('[^%.]+') do
        if type(node) ~= 'table' then return nil end
        node = node[tonumber(p) or p]
    end
    return node
end

function Utils.cfgSet(path, value)
    local node, last = Config, nil
    for p in path:gmatch('[^%.]+') do
        if last ~= nil then
            if type(node[last]) ~= 'table' then return false end
            node = node[last]
        end
        last = tonumber(p) or p
    end
    if last == nil then return false end
    node[last] = value
    return true
end

function Utils.same(a, b)
    if type(a) == 'table' and type(b) == 'table' then return json.encode(a) == json.encode(b) end
    return a == b
end
