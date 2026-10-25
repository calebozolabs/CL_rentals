--[[ ═══════════════════════════════════════════════════════════════════════
     DESKS
     Blips, the rental agent ped (created only when you're close), the
     third-eye / [E] prompts and the return zone. Rebuilt whenever an admin
     saves a desk.
     ═══════════════════════════════════════════════════════════════════════ ]]

Desks = {}

local blips, peds = {}, {}
local nearest, nearestDist = nil, math.huge
local watcher = false

local function v3(p) return vec3(p.x + 0.0, p.y + 0.0, p.z + 0.0) end

--- Closest distance from coords to a desk (the agent or a spawn point).
local function deskDistance(loc, coords)
    local best = #(coords - v3(loc.ped.coords))
    for _, p in ipairs(loc.spawns or {}) do
        local d = #(coords - v3(p))
        if d < best then best = d end
    end
    return best
end
Desks.Distance = deskDistance

--- The rental (from State.rentals) this vehicle belongs to.
function Desks.RentalOf(vehicle)
    if not vehicle or vehicle == 0 then return nil end
    local plate = Utils.plate(GetVehicleNumberPlateText(vehicle))
    for _, r in ipairs(State.rentals) do
        if r.plate == plate then return r end
    end
end

local function tryReturn(loc)
    local ok, data = Client.Act('returnVehicle', loc.id)
    if ok and data and data.contract then Client.ShowContract(data.contract) end
end

--[[ ─── Agent peds ─────────────────────────────────────────────────────── ]]

local function targetOptions(loc)
    return {
        {
            name = 'cl_rentals_browse', label = Utils.t('target_browse'), icon = 'fas fa-car', distance = 2.5,
            onSelect = function() Client.OpenDesk(loc.id) end,
        },
        {
            name = 'cl_rentals_return', label = Utils.t('target_return'), icon = 'fas fa-key', distance = 2.5,
            canInteract = function() return #State.rentals > 0 end,
            onSelect = function() tryReturn(loc) end,
        },
        {
            name = 'cl_rentals_mine', label = Utils.t('target_mine'), icon = 'fas fa-file-contract', distance = 2.5,
            canInteract = function() return #State.rentals > 0 end,
            onSelect = function() Client.OpenMine() end,
        },
    }
end

local function spawnPed(loc)
    if peds[loc.id] then return end
    peds[loc.id] = { entity = 0, pending = true }
    local ok, model = pcall(lib.requestModel, loc.ped.model, 5000)
    if not ok or not model then
        print(('^3[CL_rentals] agent model %s for %s did not load^7'):format(loc.ped.model, loc.id))
        model = lib.requestModel(Config.NewLocation.ped, 5000)
    end
    if not peds[loc.id] then SetModelAsNoLongerNeeded(model) return end   -- cleared while loading
    local c = loc.ped.coords
    local ped = CreatePed(4, model, c.x, c.y, c.z - 1.0, c.w or 0.0, false, true)
    SetModelAsNoLongerNeeded(model)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)
    SetPedCanRagdoll(ped, false)
    SetPedFleeAttributes(ped, 0, false)
    if Config.PedScenario then TaskStartScenarioInPlace(ped, Config.PedScenario, 0, true) end
    peds[loc.id] = { entity = ped }
    if Config.Interaction == 'target' then Target.addLocalEntity(ped, targetOptions(loc)) end
end

local function deletePed(id)
    local p = peds[id]
    peds[id] = nil
    if not p or not p.entity or p.entity == 0 then return end
    if Config.Interaction == 'target' then pcall(Target.removeLocalEntity, p.entity) end
    if DoesEntityExist(p.entity) then DeleteEntity(p.entity) end
end

--[[ ─── Near a desk: prompts & return zone (every frame) ─────────────────── ]]

local function nearLoop()
    if watcher then return end
    watcher = true
    CreateThread(function()
        local key = Config.InteractKey
        local color = Theme.returnMarker or { 45, 212, 191, 90 }
        while nearest and nearestDist <= (nearest.radius or 30.0) + 15.0 do
            local loc = nearest
            local sleep = 0
            local ped = cache.ped
            local coords = GetEntityCoords(ped)
            local vehicle = cache.vehicle
            local rental = vehicle and Desks.RentalOf(vehicle)

            if State.menuOpen or State.docOpen or State.placing then
                Bridge.HideText()
                sleep = 250
            elseif rental and GetPedInVehicleSeat(vehicle, -1) == ped then
                local center = v3(loc.ped.coords)
                DrawMarker(1, center.x, center.y, center.z - 1.0, 0, 0, 0, 0, 0, 0, loc.radius * 2.0, loc.radius * 2.0, 1.0,
                    color[1], color[2], color[3], color[4], false, false, 2, false, nil, nil, false)
                if deskDistance(loc, coords) <= loc.radius then
                    Bridge.ShowText(Utils.t('prompt_return', rental.label), 'key')
                    if IsControlJustReleased(0, key) then
                        Bridge.HideText()
                        tryReturn(loc)
                        Wait(1000)
                    end
                else
                    Bridge.HideText()
                end
            elseif not vehicle and Config.Interaction == 'textui' and #(coords - v3(loc.ped.coords)) <= 2.2 then
                Bridge.ShowText(Utils.t(#State.rentals > 0 and 'prompt_desk_return' or 'prompt_desk'), 'car')
                if IsControlJustReleased(0, key) then
                    Bridge.HideText()
                    Client.OpenDesk(loc.id)
                elseif #State.rentals > 0 and IsControlJustReleased(0, 47) then   -- [G]
                    Bridge.HideText()
                    tryReturn(loc)
                    Wait(1000)
                end
            else
                Bridge.HideText()
                sleep = 200
            end
            Wait(sleep)
        end
        Bridge.HideText()
        watcher = false
    end)
end

--[[ ─── Build / proximity ──────────────────────────────────────────────── ]]

function Desks.Clear()
    for _, blip in pairs(blips) do RemoveBlip(blip) end
    blips = {}
    for id in pairs(peds) do deletePed(id) end
    nearest, nearestDist = nil, math.huge
end

function Desks.Build()
    Desks.Clear()
    for _, loc in ipairs(State.locations) do
        if loc.enabled and loc.blip and loc.blip.enabled then
            local c = loc.ped.coords
            local blip = AddBlipForCoord(c.x, c.y, c.z)
            SetBlipSprite(blip, loc.blip.sprite)
            SetBlipColour(blip, loc.blip.color)
            SetBlipScale(blip, loc.blip.scale + 0.0)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(loc.label)
            EndTextCommandSetBlipName(blip)
            blips[loc.id] = blip
        end
    end
end

--- Rentals changed: nothing to rebuild, the prompts read State.rentals live.
function Desks.Refresh() end

CreateThread(function()
    while true do
        if State.ready then
            local coords = GetEntityCoords(cache.ped)
            local best, bestDist = nil, math.huge
            for _, loc in ipairs(State.locations) do
                if loc.enabled then
                    local d = deskDistance(loc, coords)
                    if d < bestDist then best, bestDist = loc, d end
                    local pd = #(coords - v3(loc.ped.coords))
                    if pd <= Config.PedDistance then spawnPed(loc)
                    elseif peds[loc.id] then deletePed(loc.id) end
                elseif peds[loc.id] then
                    deletePed(loc.id)
                end
            end
            nearest, nearestDist = best, bestDist
            if best and bestDist <= (best.radius or 30.0) + 15.0 then nearLoop() end
        end
        Wait(750)
    end
end)
