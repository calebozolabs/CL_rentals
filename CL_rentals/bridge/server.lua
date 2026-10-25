--[[ ═══════════════════════════════════════════════════════════════════════
     SERVER BRIDGE
     Everything framework / inventory specific lives here, so the rest of the
     script works the same on every server. Adapt it freely if you run a
     custom framework, inventory or key script.

     Frameworks:   qbx_core (Qbox) · qb-core · es_extended (ESX Legacy)
     Inventories:  ox_inventory · qb-inventory (also ps- / lj-inventory) · the ESX default inventory
     Vehicle keys: p_vehiclekeys · qbx_vehiclekeys · qb-vehiclekeys · Renewed-Vehiclekeys · wasabi_carlock
                   (qs-vehiclekeys is handled in bridge/client.lua)
     ═══════════════════════════════════════════════════════════════════════ ]]

Bridge = {}

local RESOURCE = GetCurrentResourceName()
local function started(name)
    local state = GetResourceState(name)
    return state == 'started' or state == 'starting'
end

local function detectFramework()
    if Config.Framework and Config.Framework ~= 'auto' then return Config.Framework end
    if started('qbx_core') then return 'qbx' end
    if started('qb-core') then return 'qb' end
    if started('es_extended') then return 'esx' end
    error(('[%s] No supported framework found (qbx_core, qb-core or es_extended). Set Config.Framework.'):format(RESOURCE))
end

Bridge.framework = detectFramework()

local QB_INVENTORIES = { 'qb-inventory', 'ps-inventory', 'lj-inventory' }
local qbInv = 'qb-inventory'
for _, name in ipairs(QB_INVENTORIES) do
    if started(name) then qbInv = name break end
end

local function detectInventory()
    if Config.Inventory and Config.Inventory ~= 'auto' then return Config.Inventory end
    if Bridge.framework == 'qbx' or started('ox_inventory') then return 'ox_inventory' end   -- Qbox always runs ox_inventory
    for _, name in ipairs(QB_INVENTORIES) do
        if started(name) then return 'qb-inventory' end
    end
    return Bridge.framework == 'esx' and 'esx' or 'qb-inventory'
end

Bridge.inventory = detectInventory()

local QBCore, ESX
if Bridge.framework == 'qb' then
    QBCore = exports['qb-core']:GetCoreObject()
elseif Bridge.framework == 'esx' then
    ESX = exports.es_extended:getSharedObject()
end

local function getPlayer(src)
    if Bridge.framework == 'qbx' then
        return exports.qbx_core:GetPlayer(src)
    elseif Bridge.framework == 'qb' then
        return QBCore.Functions.GetPlayer(src)
    else
        return ESX.GetPlayerFromId(src)
    end
end

local function qbExport(name, ...)
    local args = table.pack(...)
    return pcall(function() return exports[qbInv][name](exports[qbInv], table.unpack(args, 1, args.n)) end)
end

--[[ ─── Player ─────────────────────────────────────────────────────────── ]]

--- Unique character identifier (citizenid / ESX identifier). nil while no character is loaded.
function Bridge.GetIdentifier(src)
    local player = getPlayer(src)
    if not player then return end
    if Bridge.framework == 'esx' then return player.identifier end
    return player.PlayerData.citizenid
end

--- Character name printed on the rental contract.
function Bridge.GetName(src)
    local player = getPlayer(src)
    if not player then return GetPlayerName(src) or 'Unknown' end
    if Bridge.framework == 'esx' then
        local ok, name = pcall(player.getName)
        return ok and name or GetPlayerName(src) or 'Unknown'
    end
    local info = player.PlayerData.charinfo or {}
    if info.firstname then return Utils.trim(('%s %s'):format(info.firstname, info.lastname or '')) end
    return GetPlayerName(src) or 'Unknown'
end

--- Server id of the online player using this character, or nil.
function Bridge.GetSourceByIdentifier(identifier)
    local player
    if Bridge.framework == 'qbx' then
        player = exports.qbx_core:GetPlayerByCitizenId(identifier)
    elseif Bridge.framework == 'qb' then
        player = QBCore.Functions.GetPlayerByCitizenId(identifier)
    else
        player = ESX.GetPlayerFromIdentifier(identifier)
    end
    if not player then return end
    if Bridge.framework == 'esx' then return player.source end
    return player.PlayerData.source
end

function Bridge.Notify(src, message, kind)
    if not message then return end
    TriggerClientEvent(RESOURCE .. ':client:notify', src, message, kind)
end

--- Does this character hold the licence a category asks for? (Config.Licenses)
function Bridge.HasLicense(src, key)
    if not key or key == '' then return true end
    local def = Config.Licenses[key]
    if not def then return true end
    local player = getPlayer(src)
    if not player then return false end

    if Bridge.framework == 'esx' then
        local ok, row = pcall(MySQL.scalar.await, 'SELECT 1 FROM `user_licenses` WHERE `owner` = ? AND `type` = ? LIMIT 1', { player.identifier, def.esx })
        return ok and row ~= nil
    end
    local licences = player.PlayerData.metadata and player.PlayerData.metadata.licences or {}
    return licences[def.qb] == true
end

--[[ ─── Money ────────────────────────────────────────────────────────────
     'cash' / 'bank' work on every framework ('cash' is 'money' on ESX). ]]

local function account(name)
    if Bridge.framework == 'esx' then return name == 'cash' and 'money' or name end
    return name == 'money' and 'cash' or name
end

function Bridge.GetMoney(src, name)
    local player = getPlayer(src)
    if not player then return 0 end
    if Bridge.framework == 'esx' then
        local acc = player.getAccount(account(name))
        return acc and acc.money or 0
    end
    return player.PlayerData.money[account(name)] or 0
end

function Bridge.RemoveMoney(src, name, amount, reason)
    amount = math.floor(amount or 0)
    if amount <= 0 then return true end
    if Bridge.GetMoney(src, name) < amount then return false end
    local player = getPlayer(src)
    if not player then return false end
    if Bridge.framework == 'esx' then
        player.removeAccountMoney(account(name), amount, reason)
        return true
    end
    return player.Functions.RemoveMoney(account(name), amount, reason or RESOURCE) and true or false
end

function Bridge.AddMoney(src, name, amount, reason)
    amount = math.floor(amount or 0)
    if amount <= 0 then return true end
    local player = getPlayer(src)
    if not player then return false end
    if Bridge.framework == 'esx' then
        player.addAccountMoney(account(name), amount, reason)
        return true
    end
    return player.Functions.AddMoney(account(name), amount, reason or RESOURCE) and true or false
end

--[[ ─── Inventory (rental contract item) ──────────────────────────────── ]]

function Bridge.ItemExists(item)
    if not item then return false end
    local ok, exists = pcall(function()
        if Bridge.inventory == 'ox_inventory' then return exports.ox_inventory:Items(item) ~= nil end
        if QBCore then return QBCore.Shared.Items[item] ~= nil end
        if ESX then
            if ESX.Items then return ESX.Items[item] ~= nil end
            return ESX.GetItemLabel and ESX.GetItemLabel(item) ~= nil
        end
        return false
    end)
    return ok and exists or false
end

local function itemBox(src, item, kind)
    local data = QBCore and QBCore.Shared.Items[item]
    if not data then return end
    TriggerClientEvent('qb-inventory:client:ItemBox', src, data, kind, 1)   -- qb-inventory 2.x
    TriggerClientEvent('inventory:client:ItemBox', src, data, kind, 1)      -- older qb-inventory, ps- / lj-inventory
end

function Bridge.AddItem(src, item, metadata)
    if Bridge.inventory == 'ox_inventory' then
        return exports.ox_inventory:AddItem(src, item, 1, metadata) and true or false
    end
    local player = getPlayer(src)
    if not player then return false end
    if Bridge.framework == 'esx' then
        if player.canCarryItem and not player.canCarryItem(item, 1) then return false end
        player.addInventoryItem(item, 1)
        return true
    end
    local ok, added = qbExport('AddItem', src, item, 1, false, metadata, RESOURCE)
    if not ok and player.Functions.AddItem then added = player.Functions.AddItem(item, 1, false, metadata) end
    if added then itemBox(src, item, 'add') end
    return added and true or false
end

--- Removes the contract paper that belongs to one rental (matched on its metadata).
function Bridge.RemoveContract(src, item, rentalId)
    local ok, err = pcall(function()
        if Bridge.inventory == 'ox_inventory' then
            local slots = exports.ox_inventory:Search(src, 'slots', item) or {}
            for _, slot in pairs(slots) do
                if slot.metadata and tonumber(slot.metadata.rentalId) == rentalId then
                    exports.ox_inventory:RemoveItem(src, item, 1, nil, slot.slot)
                    return
                end
            end
            return
        end
        local player = getPlayer(src)
        if not player then return end
        if Bridge.framework == 'esx' then
            local data = player.getInventoryItem(item)
            if data and (data.count or 0) > 0 then player.removeInventoryItem(item, 1) end
            return
        end
        for _, slot in pairs(player.PlayerData.items or {}) do
            if slot and slot.name == item and slot.info and tonumber(slot.info.rentalId) == rentalId then
                local removed = qbExport('RemoveItem', src, item, 1, slot.slot, RESOURCE)
                if not removed and player.Functions.RemoveItem then player.Functions.RemoveItem(item, 1, slot.slot) end
                itemBox(src, item, 'remove')
                return
            end
        end
    end)
    if not ok then print(('^3[%s] RemoveContract failed: %s^7'):format(RESOURCE, err)) end
end

--- Is this player holding the contract paper of a rental? (lets a renter show it to someone else)
function Bridge.HasContract(src, item, rentalId)
    if not item then return false end
    local ok, has = pcall(function()
        if Bridge.inventory == 'ox_inventory' then
            return (exports.ox_inventory:Search(src, 'count', item, { rentalId = rentalId }) or 0) > 0
        end
        if Bridge.framework == 'esx' then return false end   -- the ESX inventory has no metadata
        local player = getPlayer(src)
        for _, slot in pairs(player and player.PlayerData.items or {}) do
            if slot and slot.name == item and slot.info and tonumber(slot.info.rentalId) == rentalId then return true end
        end
        return false
    end)
    return ok and has or false
end

--- Makes the contract usable from the inventory. cb(src, metadata)
--- ox_inventory uses the client export in its item definition instead (install/README_ITEMS.md).
function Bridge.RegisterContractItem(item, cb)
    if not item or Bridge.inventory == 'ox_inventory' then return end
    if Bridge.framework == 'qbx' then
        exports.qbx_core:CreateUseableItem(item, function(src, data) cb(src, data.metadata or data.info or {}) end)
    elseif Bridge.framework == 'qb' then
        QBCore.Functions.CreateUseableItem(item, function(src, data) cb(src, data.info or data.metadata or {}) end)
    else
        ESX.RegisterUsableItem(item, function(src, _, data)
            data = type(data) == 'table' and data or {}
            cb(src, data.metadata or {})
        end)
    end
end

--[[ ─── Vehicle keys ───────────────────────────────────────────────────── ]]

local KEY_SCRIPTS = { 'p_vehiclekeys', 'qbx_vehiclekeys', 'qb-vehiclekeys', 'Renewed-Vehiclekeys', 'wasabi_carlock', 'qs-vehiclekeys' }

function Bridge.KeySystem()
    local system = Config.VehicleKeys or 'auto'
    if system ~= 'auto' then return system end
    for _, name in ipairs(KEY_SCRIPTS) do
        if started(name) then return name end
    end
    return 'none'
end

--- Gives the renter keys. `vehicle` is the server entity handle.
function Bridge.GiveKeys(src, plate, vehicle)
    local system = Bridge.KeySystem()
    local ok, err = pcall(function()
        if system == 'p_vehiclekeys' or system == 'qbx_vehiclekeys' then
            exports.qbx_vehiclekeys:GiveKeys(src, vehicle)   -- p_vehiclekeys also answers the qbx_vehiclekeys export
        elseif system == 'qb-vehiclekeys' then
            local given = pcall(function() exports['qb-vehiclekeys']:GiveKeys(src, plate) end)
            if not given then TriggerClientEvent('vehiclekeys:client:SetOwner', src, plate) end
        elseif system == 'Renewed-Vehiclekeys' then
            exports['Renewed-Vehiclekeys']:addKey(src, plate)
        elseif system == 'wasabi_carlock' then
            exports.wasabi_carlock:GiveKey(src, plate)
        end
    end)
    if not ok then print(('^3[%s] GiveKeys failed (%s): %s^7'):format(RESOURCE, system, err)) end
end

function Bridge.RemoveKeys(src, plate, vehicle)
    local system = Bridge.KeySystem()
    pcall(function()
        if system == 'p_vehiclekeys' or system == 'qbx_vehiclekeys' then
            exports.qbx_vehiclekeys:RemoveKeys(src, vehicle)
        elseif system == 'qb-vehiclekeys' then
            exports['qb-vehiclekeys']:RemoveKeys(src, plate)
        elseif system == 'Renewed-Vehiclekeys' then
            exports['Renewed-Vehiclekeys']:removeKey(src, plate)
        elseif system == 'wasabi_carlock' then
            exports.wasabi_carlock:RemoveKey(src, plate)
        end
    end)
end

--[[ ─── Player lifecycle ───────────────────────────────────────────────── ]]

function Bridge.OnPlayerLoaded(cb)
    if Bridge.framework == 'esx' then
        AddEventHandler('esx:playerLoaded', function(src) cb(src) end)
    else
        AddEventHandler('QBCore:Server:PlayerLoaded', function(player)
            cb(player and player.PlayerData and player.PlayerData.source or source)
        end)
    end
end

function Bridge.OnPlayerUnload(cb)
    if Bridge.framework == 'esx' then
        AddEventHandler('esx:playerDropped', function(src) cb(src) end)
        AddEventHandler('esx:playerLogout', function(src) cb(src or source) end)
    else
        AddEventHandler('QBCore:Server:OnPlayerUnload', function(src) cb(src or source) end)
    end
end

print(('^2[%s]^7 framework: ^5%s^7 | inventory: ^5%s^7 | keys: ^5%s^7'):format(RESOURCE, Bridge.framework, Bridge.inventory, Bridge.KeySystem()))
