--[[ ═══════════════════════════════════════════════════════════════════════
     CLIENT BRIDGE
     Edit notifications, text prompts, fuel and client-side vehicle keys here.
     ═══════════════════════════════════════════════════════════════════════ ]]

Bridge = {}

local RESOURCE = GetCurrentResourceName()
local function started(name) return GetResourceState(name) == 'started' end

local framework = Config.Framework ~= 'auto' and Config.Framework
    or (started('qbx_core') and 'qbx') or (started('qb-core') and 'qb') or (started('es_extended') and 'esx') or 'qb'
Bridge.framework = framework

local ESX
if framework == 'esx' then ESX = exports.es_extended:getSharedObject() end

--[[ ─── Notifications ────────────────────────────────────────────────────
     Every message the script shows goes through here (server messages too). ]]

function Bridge.Notify(message, kind)
    if not message then return end
    kind = kind or 'inform'
    local cfg = Config.Notify or {}
    local system = cfg.system or 'cl'

    if system == 'ox_lib' then
        lib.notify({ title = Utils.t('notify_title'), description = message, type = kind == 'warning' and 'warning' or kind, position = cfg.position, duration = cfg.duration })
    elseif system == 'qb' and framework ~= 'esx' then
        TriggerEvent('QBCore:Notify', message, kind == 'inform' and 'primary' or kind, cfg.duration)
    elseif system == 'esx' then
        TriggerEvent('esx:showNotification', message, kind == 'inform' and 'info' or kind, cfg.duration)
    else
        SendNUIMessage({ action = 'notify', data = {
            message = message, kind = kind, title = Utils.t('notify_title'),
            position = cfg.position or 'top-right', duration = cfg.duration or 6000,
        } })
    end
end

RegisterNetEvent(RESOURCE .. ':client:notify', function(message, kind)
    Bridge.Notify(message, kind)
end)

--[[ ─── Text prompts ───────────────────────────────────────────────────── ]]

local shownText
function Bridge.ShowText(text, icon)
    if shownText == text then return end
    shownText = text
    lib.showTextUI(text, { icon = icon or 'car', position = 'left-center' })
end

function Bridge.HideText()
    if not shownText then return end
    shownText = nil
    lib.hideTextUI()
end

--[[ ─── Player state ───────────────────────────────────────────────────── ]]

function Bridge.IsLoggedIn()
    if framework == 'esx' then return ESX.IsPlayerLoaded() end
    return LocalPlayer.state.isLoggedIn == true
end

function Bridge.OnPlayerLoaded(cb)
    if framework == 'esx' then
        RegisterNetEvent('esx:playerLoaded', function() cb() end)
    else
        RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function() cb() end)
    end
end

function Bridge.OnPlayerUnload(cb)
    if framework == 'esx' then
        RegisterNetEvent('esx:onPlayerLogout', function() cb() end)
    else
        RegisterNetEvent('QBCore:Client:OnPlayerUnload', function() cb() end)
    end
end

--- Used by the qb-target converter for job-locked options (this script has none).
function Bridge.HasGroup() return true end

--[[ ─── Vehicles ───────────────────────────────────────────────────────── ]]

function Bridge.VehicleLabel(model)
    local hash = type(model) == 'string' and joaat(model) or model
    local display = GetDisplayNameFromVehicleModel(hash)
    local label = display and GetLabelText(display)
    if not label or label == 'NULL' or label == '' then
        label = type(model) == 'string' and (model:sub(1, 1):upper() .. model:sub(2)) or 'Vehicle'
    end
    local make = GetMakeNameFromVehicleModel and GetLabelText(GetMakeNameFromVehicleModel(hash))
    if make and make ~= 'NULL' and make ~= '' and not label:find(make, 1, true) then label = make .. ' ' .. label end
    return label
end

local FUEL_SCRIPTS = { 'ox_fuel', 'CL_fuel', 'LegacyFuel', 'cdn-fuel', 'ps-fuel', 'lj-fuel', 'okokGasStation', 'lc_fuel', 'Renewed-Fuel' }

local function fuelSystem()
    if Config.Fuel and Config.Fuel ~= 'auto' then return Config.Fuel end
    for _, name in ipairs(FUEL_SCRIPTS) do
        if started(name) then return name end
    end
    return 'native'
end

--- Fills the tank of a freshly spawned rental. Using another fuel script? Add it here.
function Bridge.SetFuel(vehicle, level)
    level = (tonumber(level) or 100) + 0.0
    local system = fuelSystem()
    local ok = pcall(function()
        if system == 'ox_fuel' or system == 'Renewed-Fuel' then
            Entity(vehicle).state:set('fuel', level, true)
        elseif system == 'okokGasStation' then
            exports.okokGasStation:SetFuel(vehicle, level)
        elseif system ~= 'native' then
            exports[system]:SetFuel(vehicle, level)
        end
    end)
    if not ok then Entity(vehicle).state:set('fuel', level, true) end
    SetVehicleFuelLevel(vehicle, level)
end

--- Key scripts that only work client side. Server-side ones are in bridge/server.lua.
function Bridge.GiveKeys(vehicle, plate)
    local system = Config.VehicleKeys
    if system == 'auto' then system = started('qs-vehiclekeys') and 'qs-vehiclekeys' or nil end
    if system == 'qs-vehiclekeys' then
        pcall(function() exports['qs-vehiclekeys']:GiveKeys(plate, GetDisplayNameFromVehicleModel(GetEntityModel(vehicle)), true) end)
    end
end

function Bridge.RemoveKeys(plate, model)
    local system = Config.VehicleKeys
    if system == 'auto' then system = started('qs-vehiclekeys') and 'qs-vehiclekeys' or nil end
    if system == 'qs-vehiclekeys' then
        pcall(function() exports['qs-vehiclekeys']:RemoveKeys(plate, model) end)
    end
end
