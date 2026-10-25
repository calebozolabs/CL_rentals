--[[ ═══════════════════════════════════════════════════════════════════════
     RENTAL VEHICLES (client side)
     The server spawns the vehicle; the renter's client fills the tank, hands
     out client-side keys, and steps out when a rental is returned or
     repossessed. Also the ox_inventory contract export.
     ═══════════════════════════════════════════════════════════════════════ ]]

local RESOURCE = GetCurrentResourceName()

local function waitForVehicle(netId, timeout)
    local deadline = GetGameTimer() + timeout
    while GetGameTimer() < deadline do
        if NetworkDoesNetworkIdExist(netId) then
            local vehicle = NetToVeh(netId)
            if vehicle ~= 0 and DoesEntityExist(vehicle) then return vehicle end
        end
        Wait(50)
    end
end

RegisterNetEvent(RESOURCE .. ':client:vehicleReady', function(netId, plate, fuel)
    local vehicle = waitForVehicle(netId, 6000)
    if not vehicle then return end
    local deadline = GetGameTimer() + 2000
    while not NetworkHasControlOfEntity(vehicle) and GetGameTimer() < deadline do
        NetworkRequestControlOfEntity(vehicle)
        Wait(25)
    end
    SetVehicleOnGroundProperly(vehicle)
    SetVehicleDirtLevel(vehicle, 0.0)
    SetVehicleHasBeenOwnedByPlayer(vehicle, true)
    SetVehicleNeedsToBeHotwired(vehicle, false)
    Bridge.SetFuel(vehicle, fuel or 100)
    Bridge.GiveKeys(vehicle, plate)
end)

RegisterNetEvent(RESOURCE .. ':client:leaveVehicle', function(netId)
    if not netId or not NetworkDoesNetworkIdExist(netId) then return end
    local vehicle = NetToVeh(netId)
    if vehicle ~= 0 and cache.vehicle == vehicle then
        TaskLeaveVehicle(cache.ped, vehicle, 0)
    end
end)

RegisterNetEvent(RESOURCE .. ':client:removeKeys', function(plate, model)
    Bridge.RemoveKeys(plate, model)
end)

--- ox_inventory item use: `client = { export = 'CL_rentals.useContract' }` (install/README_ITEMS.md)
exports('useContract', function(_, slot)
    local id = slot and slot.metadata and slot.metadata.rentalId
    local ok, message = Client.Await('contract', id)
    if type(ok) == 'table' then return Client.ShowContract(ok) end
    Bridge.Notify(message or Utils.t('rental_not_found'), 'error')
end)
