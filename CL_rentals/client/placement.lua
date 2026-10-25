--[[ ═══════════════════════════════════════════════════════════════════════
     EDITOR PLACEMENT
     Aim where the agent / a spawn point goes and press [E].
       [Scroll]  rotate (hold [Shift] for faster)
       [G]       use my current position (or my vehicle's)
       [Backspace] / [Right click]  cancel
     ═══════════════════════════════════════════════════════════════════════ ]]

Placement = {}

local CONFIRM, CANCEL, CANCEL2, HERE, FAST = 38, 177, 25, 47, 21
local SCROLL_UP, SCROLL_DOWN = 15, 14

local function aim()
    local hit, _, coords = lib.raycast.fromCamera(1 | 16, 4, 40.0)
    if hit then return coords end
    local cam = GetFinalRenderedCamCoord()
    local rot = math.rad(1) * GetFinalRenderedCamRot(2)
    local dir = vec3(-math.sin(rot.z) * math.abs(math.cos(rot.x)), math.cos(rot.z) * math.abs(math.cos(rot.x)), math.sin(rot.x))
    local to = cam + dir * 40.0
    local water, height = TestProbeAgainstWater(cam.x, cam.y, cam.z, to.x, to.y, to.z)
    if water then return height end
end

---@param kind 'ped'|'spawn'
---@param model string? preview model (ped model for 'ped', vehicle model for 'spawn')
---@return { x: number, y: number, z: number, w: number }?
function Placement.Run(kind, model)
    if State.placing then return end
    State.placing = true

    local preview
    local ok, hash = pcall(lib.requestModel, model or (kind == 'spawn' and 'sultan' or Config.NewLocation.ped), 5000)
    if ok and hash then
        local c = GetEntityCoords(cache.ped)
        if kind == 'spawn' then
            preview = CreateVehicle(hash, c.x, c.y, c.z - 50.0, 0.0, false, false)
            SetVehicleDoorsLocked(preview, 2)
        else
            preview = CreatePed(4, hash, c.x, c.y, c.z - 50.0, 0.0, false, false)
            SetBlockingOfNonTemporaryEvents(preview, true)
        end
        SetModelAsNoLongerNeeded(hash)
        SetEntityAlpha(preview, 170, false)
        SetEntityCollision(preview, false, false)
        FreezeEntityPosition(preview, true)
        SetEntityInvincible(preview, true)
    end

    Bridge.ShowText(Utils.t(kind == 'spawn' and 'place_spawn_help' or 'place_ped_help'), 'location-crosshairs')

    local heading = GetEntityHeading(cache.ped)
    local result

    while true do
        Wait(0)
        DisableControlAction(0, SCROLL_UP, true)
        DisableControlAction(0, SCROLL_DOWN, true)
        DisableControlAction(0, 24, true)
        DisableControlAction(0, 25, true)
        DisableControlAction(0, HERE, true)
        DisableControlAction(0, 200, true)

        local step = IsControlPressed(0, FAST) and 15.0 or 3.0
        if IsDisabledControlPressed(0, SCROLL_UP) then heading = (heading + step) % 360 end
        if IsDisabledControlPressed(0, SCROLL_DOWN) then heading = (heading - step) % 360 end

        local pos = aim()
        if pos and preview then
            SetEntityCoords(preview, pos.x, pos.y, pos.z + (kind == 'spawn' and 0.5 or 0.0), false, false, false, false)
            SetEntityHeading(preview, heading)
            if kind == 'spawn' then SetVehicleOnGroundProperly(preview) end
        end

        if IsDisabledControlJustPressed(0, HERE) then
            local entity = cache.vehicle or cache.ped
            local c = GetEntityCoords(entity)
            result = { x = c.x, y = c.y, z = c.z, w = GetEntityHeading(entity) }
            if kind == 'spawn' and not cache.vehicle then result.z = c.z - 0.5 end
            break
        end
        if IsControlJustPressed(0, CONFIRM) and pos then
            local c = (preview and kind == 'spawn') and GetEntityCoords(preview) or pos
            result = { x = c.x, y = c.y, z = kind == 'ped' and pos.z + 1.0 or c.z, w = heading }
            break
        end
        if IsDisabledControlJustPressed(0, CANCEL) or IsDisabledControlJustPressed(0, CANCEL2) or IsDisabledControlJustPressed(0, 200) then
            break
        end
    end

    Bridge.HideText()
    if preview and DoesEntityExist(preview) then DeleteEntity(preview) end
    State.placing = false

    if result then
        local function r(n) return math.floor(n * 100 + 0.5) / 100 end
        result = { x = r(result.x), y = r(result.y), z = r(result.z), w = r(result.w) }
    end
    return result
end
