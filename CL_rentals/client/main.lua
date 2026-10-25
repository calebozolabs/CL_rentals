--[[ ═══════════════════════════════════════════════════════════════════════
     CLIENT CORE
     State, server pushes, opening the UI (desk / my rentals / admin) and
     startup. Nothing runs every frame unless you are near a desk.
     ═══════════════════════════════════════════════════════════════════════ ]]

State = {
    ready = false, admin = false, locations = {}, rentals = {}, skew = 0, menuOpen = false, docOpen = false, placing = false,
}

Client = {}

local RESOURCE = GetCurrentResourceName()

function Client.Await(name, ...)
    return lib.callback.await(RESOURCE .. ':server:' .. name, false, ...)
end

--- Calls the server and shows its message. Returns ok, data.
function Client.Act(name, ...)
    local ok, message, data = Client.Await(name, ...)
    if message then Bridge.Notify(message, ok and 'success' or 'error') end
    return ok, data
end

function Client.NUI(action, data)
    SendNUIMessage({ action = action, data = data })
end

--- What every UI payload carries.
function Client.Base()
    return {
        locale = Locale.ui, theme = Theme, currency = Config.CurrencySymbol, durations = Config.Durations,
        accountsOrder = Config.PaymentAccounts, admin = State.admin, imagePath = Config.VehicleImagePath or false,
    }
end

--[[ ─── Opening the UI ─────────────────────────────────────────────────── ]]

local function focus()
    SetNuiFocus(true, true)
    Bridge.HideText()
end

local function openWith(mode, data)
    local payload = Client.Base()
    payload.mode = mode
    payload.data = data
    State.menuOpen = true
    focus()
    Client.NUI('open', payload)
end

function Client.OpenDesk(locId)
    if State.menuOpen or not State.ready then return end
    local ok, message, data = Client.Await('desk', locId)
    if type(ok) == 'table' then data = ok ok = true end
    if not ok then return Bridge.Notify(message or Utils.t('error_generic'), 'error') end
    openWith('desk', data)
end

function Client.OpenMine()
    if State.menuOpen or not State.ready then return end
    local ok, message, data = Client.Await('mine')
    if type(ok) == 'table' then data = ok ok = true end
    if not ok then return Bridge.Notify(message or Utils.t('error_generic'), 'error') end
    openWith('mine', data)
end

function Client.OpenAdmin()
    if State.menuOpen or not State.ready then return end
    local ok, message, data = Client.Await('adminData')
    if type(ok) == 'table' then data = ok ok = true end
    if not ok then return Bridge.Notify(message or Utils.t('no_permission'), 'error') end
    openWith('admin', data)
end

function Client.Close()
    if not State.menuOpen then return end
    State.menuOpen = false
    if not State.docOpen then SetNuiFocus(false, false) end
    Client.NUI('close')
end

--- Shows a rental contract on its own (after renting, returning or using the paper).
function Client.ShowContract(contract)
    if not contract then return end
    State.docOpen = true
    SetNuiFocus(true, true)
    local payload = Client.Base()
    payload.contract = contract
    Client.NUI('contract', payload)
end

RegisterNetEvent(RESOURCE .. ':client:contract', function(contract)
    Client.ShowContract(contract)
end)

if Config.Commands.rentals then
    RegisterCommand(Config.Commands.rentals, function() Client.OpenMine() end, false)
end

RegisterCommand(Config.Admin.command, function()
    if not State.admin then return Bridge.Notify(Utils.t('no_permission'), 'error') end
    Client.OpenAdmin()
end, false)

--[[ ─── Server pushes ──────────────────────────────────────────────────── ]]

RegisterNetEvent(RESOURCE .. ':client:locations', function(locations)
    State.locations = locations or {}
    Desks.Build()
end)

RegisterNetEvent(RESOURCE .. ':client:rentals', function(rentals, now)
    State.rentals = rentals or {}
    if now then State.skew = now - GetCloudTimeAsInt() end
    Desks.Refresh()
    if State.menuOpen then Client.NUI('rentals', { rentals = State.rentals, now = now }) end
end)

-- Rental time warnings / renewals: a short alert sound on top of the notification
RegisterNetEvent(RESOURCE .. ':client:alert', function()
    PlaySoundFrontend(-1, 'Event_Message_Purple', 'GTAO_FM_Events_Soundset', false)
end)

--[[ ─── Startup ────────────────────────────────────────────────────────── ]]

local booting = false
local function boot()
    if booting then return end
    booting = true
    local data
    for _ = 1, 30 do
        data = lib.callback.await(RESOURCE .. ':server:bootstrap', false)
        if data then break end
        Wait(2000)
    end
    booting = false
    if not data then return end
    State.admin = data.admin
    State.locations = data.locations or {}
    State.rentals = data.rentals or {}
    State.skew = (data.now or GetCloudTimeAsInt()) - GetCloudTimeAsInt()
    State.ready = true
    Desks.Build()
    Client.NUI('init', Client.Base())
end

RegisterNetEvent(RESOURCE .. ':client:ready', function() CreateThread(boot) end)
Bridge.OnPlayerLoaded(function() CreateThread(boot) end)

AddEventHandler('onClientResourceStart', function(resource)
    if resource ~= RESOURCE then return end
    if Bridge.IsLoggedIn() then CreateThread(boot) end
end)

Bridge.OnPlayerUnload(function()
    Client.Close()
    Desks.Clear()
    State.ready = false
    State.rentals = {}
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= RESOURCE then return end
    if State.menuOpen or State.docOpen then SetNuiFocus(false, false) end
    Bridge.HideText()
    Desks.Clear()
end)
