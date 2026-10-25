--[[ ═══════════════════════════════════════════════════════════════════════
     RENTAL DESKS
     Desks live in the database and are built in /rentaladmin. On the first
     start Config.DefaultLocations is copied in. Everything the editor sends
     is rebuilt field by field here, so a modified UI can't store junk.
     ═══════════════════════════════════════════════════════════════════════ ]]

Locations = { list = {}, order = {} }

local RESOURCE = GetCurrentResourceName()

local LIMITS = { spawns = 20, categories = 20, vehicles = 150, price = 10000000 }
local VEHICLE_TYPES = { automobile = true, bike = true, boat = true, heli = true, plane = true, submarine = true, trailer = true, train = true }

local function num(v, lo, hi)
    v = tonumber(v)
    if not v or v ~= v then return nil end   -- nil / NaN
    if lo and (v < lo or v > hi) then return nil end
    return v
end

local function r2(n) return math.floor(n * 100 + 0.5) / 100 end

local function point(p, needHeading)
    if type(p) ~= 'table' then return nil end
    local x, y, z = num(p.x, -10000, 10000), num(p.y, -10000, 10000), num(p.z, -500, 3000)
    if not x or not y or not z then return nil end
    local w = num(p.w, -720, 720) or 0.0
    if needHeading == false then return { x = r2(x), y = r2(y), z = r2(z) } end
    return { x = r2(x), y = r2(y), z = r2(z), w = r2(w % 360) }
end

local function text(v, lo, hi)
    local s = Utils.trim(v)
    if #s < lo or #s > hi then return nil end
    return s
end

local function slug(v, hi)
    local s = Utils.trim(v):lower()
    if s == '' or #s > (hi or 32) or not s:match('^[%w_%-]+$') then return nil end
    return s
end

local function slugify(label)
    local s = Utils.trim(label):lower():gsub('[^%w]+', '_'):gsub('^_+', ''):gsub('_+$', '')
    if s == '' then s = 'desk' end
    return s:sub(1, 40)
end

--- Rebuilds a desk from editor input. Returns the clean desk or nil, error message.
function Locations.Validate(raw, existingId)
    if type(raw) ~= 'table' then return nil, Utils.t('invalid_location') end
    local loc = {}

    loc.label = text(raw.label, 2, 48)
    if not loc.label then return nil, Utils.t('err_label') end
    loc.enabled = raw.enabled ~= false

    local ped = type(raw.ped) == 'table' and raw.ped or {}
    loc.ped = { model = slug(ped.model, 48) or Config.NewLocation.ped, coords = point(ped.coords) }
    if not loc.ped.coords then return nil, Utils.t('err_ped') end

    local blip = type(raw.blip) == 'table' and raw.blip or {}
    loc.blip = {
        enabled = blip.enabled ~= false,
        sprite = math.floor(num(blip.sprite, 1, 900) or Config.NewLocation.blip.sprite),
        color = math.floor(num(blip.color, 0, 85) or Config.NewLocation.blip.color),
        scale = r2(num(blip.scale, 0.3, 2.0) or Config.NewLocation.blip.scale),
    }
    loc.radius = r2(num(raw.radius, 5, 100) or Config.Return.defaultRadius)

    loc.spawns = {}
    for i, p in ipairs(type(raw.spawns) == 'table' and raw.spawns or {}) do
        if i > LIMITS.spawns then break end
        local clean = point(p)
        if clean then loc.spawns[#loc.spawns + 1] = clean end
    end
    if #loc.spawns == 0 then return nil, Utils.t('err_spawns') end

    loc.categories = {}
    local catIds = {}
    for i, c in ipairs(type(raw.categories) == 'table' and raw.categories or {}) do
        if i > LIMITS.categories then break end
        if type(c) == 'table' then
            local id = slug(c.id) or slugify(c.label or '')
            local label = text(c.label, 1, 32)
            if not label then return nil, Utils.t('err_category_label') end
            while catIds[id] do id = id .. '_' end
            catIds[id] = true
            loc.categories[#loc.categories + 1] = {
                id = id, label = label,
                icon = Utils.contains(Config.CategoryIcons, c.icon) and c.icon or 'car',
                license = (c.license and Config.Licenses[c.license]) and c.license or nil,
            }
        end
    end
    if #loc.categories == 0 then return nil, Utils.t('err_categories') end

    loc.vehicles = {}
    local models = {}
    for i, v in ipairs(type(raw.vehicles) == 'table' and raw.vehicles or {}) do
        if i > LIMITS.vehicles then break end
        if type(v) == 'table' then
            local model = slug(v.model, 32)
            if not model then return nil, Utils.t('err_model') end
            if models[model] then return nil, Utils.t('err_model_twice', model) end
            models[model] = true
            if not catIds[v.category] then return nil, Utils.t('err_vehicle_category', model) end

            local prices, any = {}, false
            for _, d in ipairs(Config.Durations) do
                local p = v.prices and v.prices[d.id]
                if p ~= nil and p ~= '' then
                    p = num(p, 0, LIMITS.price)
                    if not p then return nil, Utils.t('err_price', model) end
                    prices[d.id] = math.floor(p)
                    any = true
                end
            end
            if not any then return nil, Utils.t('err_no_price', model) end

            local deposit = v.deposit
            if deposit ~= nil and deposit ~= '' then
                deposit = num(deposit, 0, LIMITS.price)
                if not deposit then return nil, Utils.t('err_deposit', model) end
                deposit = math.floor(deposit)
            else
                deposit = nil
            end

            loc.vehicles[#loc.vehicles + 1] = {
                model = model,
                label = text(v.label, 1, 48) or model,
                type = VEHICLE_TYPES[v.type] and v.type or 'automobile',
                category = v.category,
                prices = prices,
                deposit = deposit,
            }
        end
    end

    if existingId and Locations.list[existingId] then
        loc.id = existingId
    else
        local base = slug(raw.id, 40) or slugify(loc.label)
        local id, n = base, 1
        while Locations.list[id] do n = n + 1 id = base .. '_' .. n end
        loc.id = id
    end
    return loc
end

function Locations.Load()
    local rows = DB.Locations()
    if #rows == 0 then
        for i, def in ipairs(Config.DefaultLocations or {}) do
            local loc, err = Locations.Validate(def)
            if loc then
                loc.id = def.id or loc.id
                Locations.list[loc.id] = loc
                Locations.order[#Locations.order + 1] = loc.id
                DB.SaveLocation(loc, i)
            else
                print(('^3[%s] default desk %s skipped: %s^7'):format(RESOURCE, tostring(def.id), err))
            end
        end
        return
    end
    for _, row in ipairs(rows) do
        local data = DB.decode(row.data, nil)
        local loc = data and Locations.Validate(data, nil)
        if loc then
            loc.id = row.id
            Locations.list[row.id] = loc
            Locations.order[#Locations.order + 1] = row.id
        else
            print(('^3[%s] desk %s in the database could not be read and was skipped^7'):format(RESOURCE, row.id))
        end
    end
end

function Locations.Get(id)
    return id and Locations.list[id] or nil
end

function Locations.Vehicle(loc, model)
    for _, v in ipairs(loc.vehicles) do
        if v.model == model then return v end
    end
end

function Locations.Category(loc, id)
    for _, c in ipairs(loc.categories) do
        if c.id == id then return c end
    end
end

--- Every desk, in order (sent to clients — nothing secret in here).
function Locations.Public()
    local out = {}
    for _, id in ipairs(Locations.order) do
        local loc = Locations.list[id]
        if loc then out[#out + 1] = loc end
    end
    return out
end

local function publish()
    TriggerClientEvent(RESOURCE .. ':client:locations', -1, Locations.Public())
end

function Locations.Save(loc)
    local isNew = not Locations.list[loc.id]
    Locations.list[loc.id] = loc
    if isNew then Locations.order[#Locations.order + 1] = loc.id end
    local sort = 0
    for i, id in ipairs(Locations.order) do if id == loc.id then sort = i end end
    DB.SaveLocation(loc, sort)
    publish()
end

function Locations.Delete(id)
    if not Locations.list[id] then return false end
    Locations.list[id] = nil
    for i, v in ipairs(Locations.order) do
        if v == id then table.remove(Locations.order, i) break end
    end
    DB.DeleteLocation(id)
    publish()
    return true
end

--- Distance from coords to the desk (the agent or any spawn point, whichever is closer).
function Locations.Distance(loc, coords)
    local best = #(coords - Utils.toVec3(loc.ped.coords))
    for _, p in ipairs(loc.spawns) do
        local d = #(coords - Utils.toVec3(p))
        if d < best then best = d end
    end
    return best
end
