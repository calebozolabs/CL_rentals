--[[ ═══════════════════════════════════════════════════════════════════════
     NUI CALLBACKS
     The UI calls server actions through `call` (whitelisted names only).
     The server re-validates everything: a modified UI can only ask, never
     decide. Editor helpers that need the game world (positions, model
     checks, placement) are answered here.
     ═══════════════════════════════════════════════════════════════════════ ]]

local ALLOWED = {}
for _, name in ipairs({
    'desk', 'rent', 'mine', 'extend', 'locate', 'contract', 'returnVehicle',
    'adminData', 'adminSaveLocation', 'adminDeleteLocation', 'adminEndRental', 'adminSetting', 'adminResetSetting',
}) do ALLOWED[name] = true end

--- Normalises the callback return shapes into { ok, message, data }.
local function normalise(a, b, c)
    if type(a) == 'table' and b == nil then return { ok = true, data = a } end
    if a == true then return { ok = true, message = b, data = c } end
    if a == false then return { ok = false, message = b, data = c } end
    if a == nil then return { ok = false } end
    return { ok = true, data = a }
end

RegisterNUICallback('call', function(data, cb)
    local name = data and data.name
    if not ALLOWED[name] then return cb({ ok = false }) end
    local args = type(data.args) == 'table' and data.args or {}
    cb(normalise(Client.Await(name, table.unpack(args, 1, data.argc or #args))))
end)

--- The menu closed. keepFocus: a contract is still on screen.
RegisterNUICallback('close', function(data, cb)
    State.menuOpen = false
    if data and data.keepFocus then
        State.docOpen = true
    elseif not State.docOpen then
        SetNuiFocus(false, false)
    end
    cb(1)
end)

RegisterNUICallback('docClose', function(_, cb)
    State.docOpen = false
    if not State.menuOpen then SetNuiFocus(false, false) end
    cb(1)
end)

RegisterNUICallback('waypoint', function(data, cb)
    if data and data.x and data.y then SetNewWaypoint(data.x + 0.0, data.y + 0.0) end
    cb(1)
end)

--[[ ─── Editor helpers (admins only — the server checks again on save) ─── ]]

local function vehicleType(hash)
    local class = GetVehicleClassFromName(hash)
    if class == 8 or class == 13 then return 'bike' end
    if class == 14 then return 'boat' end
    if class == 15 then return 'heli' end
    if class == 16 then return 'plane' end
    if class == 21 then return 'train' end
    if IsThisModelATrain and IsThisModelATrain(hash) then return 'train' end
    return 'automobile'
end

RegisterNUICallback('modelInfo', function(data, cb)
    if not State.admin then return cb({ ok = false }) end
    local model = Utils.trim(data and data.model or ''):lower()
    local hash = joaat(model)
    if model == '' or not IsModelInCdimage(hash) then return cb({ ok = false, message = Utils.t('model_missing', model) }) end
    if data.kind == 'ped' then
        if not IsModelAPed(hash) then return cb({ ok = false, message = Utils.t('model_not_ped', model) }) end
        return cb({ ok = true })
    end
    if not IsModelAVehicle(hash) then return cb({ ok = false, message = Utils.t('model_not_vehicle', model) }) end
    cb({ ok = true, data = { model = model, label = Bridge.VehicleLabel(model), type = vehicleType(hash) } })
end)

RegisterNUICallback('here', function(_, cb)
    if not State.admin then return cb(false) end
    local entity = cache.vehicle or cache.ped
    local c = GetEntityCoords(entity)
    local function r(n) return math.floor(n * 100 + 0.5) / 100 end
    cb({ x = r(c.x), y = r(c.y), z = r(c.z), w = r(GetEntityHeading(entity)) })
end)

RegisterNUICallback('place', function(data, cb)
    if not State.admin or State.placing then return cb(false) end
    SetNuiFocus(false, false)
    Client.NUI('hide', true)
    local result = Placement.Run(data.kind == 'spawn' and 'spawn' or 'ped', data.model)
    Client.NUI('hide', false)
    SetNuiFocus(true, true)
    cb(result or false)
end)

RegisterNUICallback('teleport', function(data, cb)
    if not State.admin or not data or not data.x then return cb(false) end
    local ped = cache.ped
    DoScreenFadeOut(250)
    Wait(260)
    SetEntityCoords(ped, data.x + 0.0, data.y + 0.0, (data.z or 0.0) + 0.0, false, false, false, false)
    if data.w then SetEntityHeading(ped, data.w + 0.0) end
    Wait(300)
    DoScreenFadeIn(250)
    cb(true)
end)
