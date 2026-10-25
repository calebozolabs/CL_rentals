--[[ ═══════════════════════════════════════════════════════════════════════
     IN-GAME SETTINGS
     The values /rentaladmin → Settings can change. Every value is checked
     here before it is saved; edits are stored in cl_rentals_settings and win
     over shared/config.lua until they are reset.
     ═══════════════════════════════════════════════════════════════════════ ]]

Settings = {}

local SCHEMA = {
    { group = 'rentals', key = 'Rentals.maxActive',       type = 'int',    min = 1, max = 10 },
    { group = 'rentals', key = 'Rentals.platePrefix',     type = 'string', min = 1, max = 5, pattern = '^[A-Z]+$', upper = true },
    { group = 'rentals', key = 'Rentals.spawnCooldown',   type = 'int',    min = 0, max = 300 },
    { group = 'rentals', key = 'Rentals.warpIntoVehicle', type = 'bool' },
    { group = 'rentals', key = 'Rentals.fuel',            type = 'int',    min = 1, max = 100 },
    { group = 'rentals', key = 'Rentals.extendAnywhere',  type = 'bool' },
    { group = 'deposit', key = 'Deposit.enabled',         type = 'bool' },
    { group = 'deposit', key = 'Deposit.amount',          type = 'int',    min = 0, max = 1000000 },
    { group = 'deposit', key = 'Deposit.damageDeduction', type = 'bool' },
    { group = 'expiry',  key = 'Expiry.mode',             type = 'select', options = { 'recharge', 'repossess' } },
    { group = 'expiry',  key = 'Expiry.warnings',         type = 'list',   min = 1, max = 120, count = 4 },
    { group = 'expiry',  key = 'Expiry.maxRecharges',     type = 'int',    min = 0, max = 50 },
    { group = 'expiry',  key = 'Expiry.grace',            type = 'int',    min = 0, max = 120 },
    { group = 'return',  key = 'Return.anyLocation',      type = 'bool' },
    { group = 'contract', key = 'Contract.removeOnReturn', type = 'bool' },
    { group = 'contract', key = 'RefundOnRestart',        type = 'bool' },
}

local byKey, defaults, overridden = {}, {}, {}
for _, field in ipairs(SCHEMA) do
    byKey[field.key] = field
    defaults[field.key] = Utils.copy(Utils.cfgGet(field.key))
end

--- Cleans a value for a field. Returns value or nil, error.
local function clean(field, value)
    local t = field.type
    if t == 'bool' then
        if type(value) ~= 'boolean' then return nil, 'invalid' end
        return value
    elseif t == 'int' then
        local n = tonumber(value)
        if not n then return nil, 'invalid' end
        n = math.floor(n)
        if n < field.min or n > field.max then return nil, 'range' end
        return n
    elseif t == 'string' then
        local s = Utils.trim(value)
        if field.upper then s = s:upper() end
        if #s < field.min or #s > field.max then return nil, 'range' end
        if field.pattern and not s:match(field.pattern) then return nil, 'invalid' end
        return s
    elseif t == 'select' then
        if not Utils.contains(field.options, value) then return nil, 'invalid' end
        return value
    elseif t == 'list' then
        if type(value) ~= 'table' or #value < 1 or #value > field.count then return nil, 'range' end
        local out, seen = {}, {}
        for _, v in ipairs(value) do
            local n = math.floor(tonumber(v) or -1)
            if n < field.min or n > field.max then return nil, 'range' end
            if not seen[n] then seen[n] = true out[#out + 1] = n end
        end
        table.sort(out, function(a, b) return a > b end)
        return out
    end
    return nil, 'invalid'
end

function Settings.Load()
    for _, row in ipairs(DB.Settings()) do
        local field = byKey[row.key]
        local stored = DB.decode(row.value, nil)
        if field and stored then
            local value = clean(field, stored.v)
            if value ~= nil then
                Utils.cfgSet(field.key, value)
                overridden[field.key] = true
            end
        end
    end
end

--- Rows for the editor.
function Settings.Rows()
    local rows = {}
    for _, field in ipairs(SCHEMA) do
        rows[#rows + 1] = {
            key = field.key, group = field.group, type = field.type, min = field.min, max = field.max, options = field.options,
            value = Utils.cfgGet(field.key), default = defaults[field.key], changed = overridden[field.key] == true,
        }
    end
    return rows
end

---@return boolean ok, string? error
function Settings.Set(key, value, by)
    local field = byKey[key]
    if not field then return false, Utils.t('setting_unknown') end
    local cleaned, err = clean(field, value)
    if cleaned == nil then return false, Utils.t(err == 'range' and 'setting_range' or 'setting_invalid') end
    Utils.cfgSet(key, cleaned)
    if Utils.same(cleaned, defaults[key]) then
        overridden[key] = nil
        DB.DeleteSetting(key)
    else
        overridden[key] = true
        DB.SaveSetting(key, cleaned, by)
    end
    return true
end

function Settings.Reset(key)
    if not byKey[key] then return false end
    Utils.cfgSet(key, Utils.copy(defaults[key]))
    overridden[key] = nil
    DB.DeleteSetting(key)
    return true
end
