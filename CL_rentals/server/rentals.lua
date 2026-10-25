--[[ ═══════════════════════════════════════════════════════════════════════
     RENTALS
     Renting, the contract, returning, extending and what happens when the
     time runs out. The server spawns every rental vehicle and keeps the
     clock: clients only ask.

     Time running out (Config.Expiry):
       · the renter is warned `warnings` minutes before the end
       · 'recharge'  the price of the same period is charged again and the
                     rental continues — until the renter can't pay, is
                     offline, or `maxRecharges` is reached: then the vehicle
                     is repossessed and the deposit kept
       · 'repossess' after `grace` minutes overdue the vehicle is taken
     ═══════════════════════════════════════════════════════════════════════ ]]

Rentals = { active = {} }   -- rental id -> rental

local RESOURCE = GetCurrentResourceName()
local lastRent = {}

--[[ ─── Helpers ────────────────────────────────────────────────────────── ]]

local function imageOf(model)
    return Config.VehicleImagePath and Config.VehicleImagePath:format(model) or nil
end

local function depositFor(vehicle)
    if not Config.Deposit.enabled then return 0 end
    return math.floor(vehicle.deposit or Config.Deposit.amount or 0)
end

local function waitFor(check, timeout)
    local deadline = GetGameTimer() + timeout
    while not check() do
        if GetGameTimer() > deadline then return false end
        Wait(25)
    end
    return true
end

local function accounts(src)
    local out = {}
    for _, id in ipairs(Config.PaymentAccounts) do
        out[#out + 1] = { id = id, balance = Bridge.GetMoney(src, id) }
    end
    return out
end

--- Charges `amount` from `preferred`, then the other payment accounts. Returns the account used.
local function chargeAny(src, amount, preferred, reason)
    if amount <= 0 then return preferred or Config.PaymentAccounts[1] end
    local order = {}
    if preferred and Utils.contains(Config.PaymentAccounts, preferred) then order[1] = preferred end
    for _, id in ipairs(Config.PaymentAccounts) do
        if id ~= preferred then order[#order + 1] = id end
    end
    for _, id in ipairs(order) do
        if Bridge.GetMoney(src, id) >= amount and Bridge.RemoveMoney(src, id, amount, reason) then return id end
    end
end

local function ofCid(cid)
    local out = {}
    for _, r in pairs(Rentals.active) do
        if r.cid == cid then out[#out + 1] = r end
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

local function plateTaken(plate)
    for _, r in pairs(Rentals.active) do
        if r.plate == plate then return true end
    end
    return false
end

local function newPlate()
    local prefix = tostring(Config.Rentals.platePrefix or 'RENT'):upper():sub(1, 5)
    local digits = 8 - #prefix
    for _ = 1, 50 do
        local plate = prefix .. tostring(math.random(10 ^ (digits - 1), 10 ^ digits - 1))
        if not plateTaken(plate) then return plate end
    end
    return prefix .. tostring(math.random(10 ^ (digits - 1), 10 ^ digits - 1))
end

local function entityOf(r)
    if r.entity and DoesEntityExist(r.entity) then return r.entity end
    return nil
end

--[[ ─── What the client sees ───────────────────────────────────────────── ]]

local function public(r)
    return {
        id = r.id, contract = Utils.contractNo(r.id), label = r.label, model = r.model, plate = r.plate, image = imageOf(r.model),
        location = r.location, locationLabel = r.locationLabel, category = r.categoryLabel, minutes = r.minutes,
        durationLabel = Utils.durationLabel(r.minutes), price = r.price, deposit = r.deposit, paid = r.paid,
        startedAt = r.startedAt, expiresAt = r.expiresAt, status = r.status, recharges = r.recharges, netId = r.netId,
    }
end

function Rentals.ListFor(cid)
    local out = {}
    for _, r in ipairs(ofCid(cid)) do out[#out + 1] = public(r) end
    return out
end

local function push(cid)
    local src = Server.SourceOf(cid)
    if src then TriggerClientEvent(RESOURCE .. ':client:rentals', src, Rentals.ListFor(cid), os.time()) end
end

--- The rental contract (an active rental or a history row).
function Rentals.Contract(r)
    local row = r.cid and r or {
        id = r.id, cid = r.identifier, name = r.name, label = r.label, model = r.model, plate = r.plate,
        location = r.location, locationLabel = r.location_label, categoryLabel = r.category, minutes = r.minutes,
        durationId = r.duration_id, price = r.price, deposit = r.deposit, paid = r.paid, recharges = r.recharges,
        startedAt = r.started_at, expiresAt = r.expires_at, endedAt = r.ended_at, status = r.status, refund = r.refund, damage = r.damage,
    }
    return {
        id = row.id, no = Utils.contractNo(row.id), renter = row.name, vehicle = row.label, model = row.model, plate = row.plate,
        image = imageOf(row.model), category = row.categoryLabel, location = row.locationLabel, durationLabel = Utils.durationLabel(row.minutes),
        price = row.price, deposit = row.deposit, paid = row.paid, recharges = row.recharges or 0, startedAt = row.startedAt,
        expiresAt = row.expiresAt, endedAt = row.endedAt, status = row.status, refund = row.refund, damage = row.damage,
        terms = {
            mode = Config.Expiry.mode, maxRecharges = Config.Expiry.maxRecharges, grace = Config.Expiry.grace,
            anyLocation = Config.Return.anyLocation, damageDeduction = Config.Deposit.damageDeduction,
        },
        now = os.time(),
    }
end

--[[ ─── Sessions (main.lua) ─────────────────────────────────────────────── ]]

function Rentals.Attach(src, cid)
    for _, r in pairs(Rentals.active) do
        if r.cid == cid then r.src = src end
    end
end

function Rentals.Detach(src)
    for _, r in pairs(Rentals.active) do
        if r.src == src then r.src = nil end
    end
    lastRent[src] = nil
end

--[[ ─── Spawning ───────────────────────────────────────────────────────── ]]

local function freeSpawn(loc)
    local vehicles = GetAllVehicles()
    for _, p in ipairs(loc.spawns) do
        local pos = vec3(p.x, p.y, p.z)
        local free = true
        for _, vehicle in ipairs(vehicles) do
            if #(GetEntityCoords(vehicle) - pos) < 3.0 then free = false break end
        end
        if free then return p end
    end
end

local function spawn(src, vehicle, point, plate)
    local entity = CreateVehicleServerSetter(joaat(vehicle.model), vehicle.type or 'automobile', point.x, point.y, point.z, point.w or 0.0)
    if not waitFor(function() return entity and entity ~= 0 and DoesEntityExist(entity) end, 5000) then
        print(('^3[%s] could not spawn %s — is the model on this server?^7'):format(RESOURCE, vehicle.model))
        return nil
    end
    waitFor(function() return GetVehicleNumberPlateText(entity) ~= '' end, 2000)
    SetVehicleNumberPlateText(entity, plate)
    if SetEntityOrphanMode then SetEntityOrphanMode(entity, 2) end   -- keep it when the renter logs off
    SetEntityRoutingBucket(entity, GetPlayerRoutingBucket(src))
    SetVehicleDoorsLocked(entity, 1)

    if Config.Rentals.warpIntoVehicle then
        local ped = GetPlayerPed(src)
        waitFor(function()
            SetPedIntoVehicle(ped, entity, -1)
            return GetVehiclePedIsIn(ped, false) == entity
        end, 2000)
    end
    return entity, NetworkGetNetworkIdFromEntity(entity)
end

--- Gets everyone out, then deletes the vehicle.
local function removeVehicle(r)
    local entity = entityOf(r)
    r.entity = nil
    if not entity then return end
    TriggerClientEvent(RESOURCE .. ':client:leaveVehicle', -1, r.netId)
    SetTimeout(2500, function()
        if DoesEntityExist(entity) then DeleteEntity(entity) end
    end)
end

--[[ ─── Ending a rental ────────────────────────────────────────────────── ]]

--- status: returned | repossessed | lost | ended (admin)
local function finish(r, status, refund, damage)
    Rentals.active[r.id] = nil
    r.status = status
    r.refund = math.max(0, math.floor(refund or 0))
    r.damage = damage or 0
    r.endedAt = os.time()

    local src = r.src
    if src and r.plate then
        Bridge.RemoveKeys(src, r.plate, entityOf(r))
        TriggerClientEvent(RESOURCE .. ':client:removeKeys', src, r.plate, r.model)
        if Config.Contract.item and Config.Contract.removeOnReturn then Bridge.RemoveContract(src, Config.Contract.item, r.id) end
    end
    removeVehicle(r)

    if r.refund > 0 then
        if not (src and Bridge.AddMoney(src, r.account, r.refund, 'rental-deposit-refund')) then
            -- offline: paid on the next login
            MySQL.update.await('UPDATE `cl_rentals_history` SET `refund_due` = ? WHERE `id` = ?', { r.refund, r.id })
        end
    end
    DB.UpdateRental(r)
    push(r.cid)
end

local function repossess(r, reason)
    local src = r.src
    finish(r, 'repossessed', 0)
    if src then Bridge.Notify(src, Utils.t('repossessed_' .. reason, r.label, r.plate, Utils.formatMoney(r.price)), 'error') end
    Utils.debug('repossessed', r.id, r.plate, reason)
end

--[[ ─── The clock ──────────────────────────────────────────────────────── ]]

local function maxedOut(r)
    local max = Config.Expiry.maxRecharges or 0
    return max > 0 and r.recharges >= max
end

local function warn(r, remain)
    local src = r.src
    if not src then return end
    local left = Utils.durationLabel(math.max(1, math.ceil(remain / 60)))
    local message
    if Config.Expiry.mode == 'repossess' then
        message = Utils.t('warn_repossess', r.label, r.plate, left, Config.Expiry.grace)
    elseif maxedOut(r) then
        message = Utils.t('warn_final', r.label, r.plate, left)
    else
        message = Utils.t('warn_recharge', r.label, r.plate, left, Utils.formatMoney(r.price), Utils.durationLabel(r.minutes))
    end
    Bridge.Notify(src, message, 'warning')
    TriggerClientEvent(RESOURCE .. ':client:alert', src)
end

local function expire(r, now)
    if Config.Expiry.mode == 'repossess' then
        if now >= r.expiresAt + (Config.Expiry.grace or 0) * 60 then return repossess(r, 'overdue') end
        if r.status ~= 'overdue' then
            r.status = 'overdue'
            DB.UpdateRental(r)
            push(r.cid)
            if r.src then Bridge.Notify(r.src, Utils.t('overdue_repossess', r.label, r.plate, Config.Expiry.grace), 'error') end
        end
        return
    end

    -- 'recharge'
    if maxedOut(r) then return repossess(r, 'limit') end
    if not r.src then return repossess(r, 'offline') end
    local used = chargeAny(r.src, r.price, r.account, 'vehicle-rental-renewal')
    if not used then return repossess(r, 'unpaid') end

    r.recharges = r.recharges + 1
    r.paid = r.paid + r.price
    r.expiresAt = r.expiresAt + r.minutes * 60
    r.warned = {}
    r.status = 'active'
    DB.UpdateRental(r)
    push(r.cid)
    Bridge.Notify(r.src, Utils.t('recharged', r.label, r.plate, Utils.formatMoney(r.price), Utils.durationLabel(r.minutes)), 'warning')
    TriggerClientEvent(RESOURCE .. ':client:alert', r.src)
end

local function tick()
    local now = os.time()
    for _, r in pairs(Rentals.active) do
        if not entityOf(r) then
            local src = r.src
            finish(r, 'lost', 0)
            if src then Bridge.Notify(src, Utils.t('vehicle_lost', r.label, r.plate), 'error') end
        else
            local remain = r.expiresAt - now
            if remain > 0 then
                for _, minutes in ipairs(Config.Expiry.warnings or {}) do
                    if remain <= minutes * 60 and not r.warned[minutes] and minutes * 60 < r.minutes * 60 then
                        -- mark every larger mark too, so a short rental doesn't get several at once
                        for _, m in ipairs(Config.Expiry.warnings) do if m >= minutes then r.warned[m] = true end end
                        warn(r, remain)
                        break
                    end
                end
            else
                expire(r, now)
            end
        end
    end
end

function Rentals.Start()
    CreateThread(function()
        while true do
            Wait(5000)
            local ok, err = pcall(tick)
            if not ok then print(('^1[%s] rental clock error: %s^7'):format(RESOURCE, err)) end
        end
    end)
end

--[[ ─── Rent ───────────────────────────────────────────────────────────── ]]

local function nearDesk(src, loc, extra)
    local coords = GetEntityCoords(GetPlayerPed(src))
    return #(coords - Utils.toVec3(loc.ped.coords)) <= (extra or Config.Security.deskDistance)
end

local function deskView(src, loc)
    local vehicles = {}
    for _, v in ipairs(loc.vehicles) do
        vehicles[#vehicles + 1] = {
            model = v.model, label = v.label, type = v.type, category = v.category, prices = v.prices,
            deposit = depositFor(v), image = imageOf(v.model),
        }
    end
    local categories = {}
    for _, c in ipairs(loc.categories) do
        categories[#categories + 1] = { id = c.id, label = c.label, icon = c.icon, license = c.license, licensed = Bridge.HasLicense(src, c.license) }
    end
    return { id = loc.id, label = loc.label, categories = categories, vehicles = vehicles }
end

Server.Register('desk', function(src, s, locId)
    local loc = Locations.Get(locId)
    if not loc or not loc.enabled then return false, Utils.t('desk_closed') end
    if not nearDesk(src, loc, Config.Security.deskDistance + 5.0) then return false, Utils.t('too_far') end
    return {
        location = deskView(src, loc), accounts = accounts(src), name = s.name, rentals = Rentals.ListFor(s.cid),
        maxActive = Config.Rentals.maxActive, expiry = { mode = Config.Expiry.mode, maxRecharges = Config.Expiry.maxRecharges, grace = Config.Expiry.grace },
        depositEnabled = Config.Deposit.enabled, damageDeduction = Config.Deposit.damageDeduction, now = os.time(),
    }
end)

Server.Register('rent', function(src, s, locId, model, durationId, account)
    local loc = Locations.Get(locId)
    if not loc or not loc.enabled then return false, Utils.t('desk_closed') end
    if not nearDesk(src, loc) then return false, Utils.t('too_far') end

    local vehicle = type(model) == 'string' and Locations.Vehicle(loc, model)
    if not vehicle then return false, Utils.t('vehicle_unavailable') end
    local duration = Utils.duration(durationId)
    local price = duration and vehicle.prices[duration.id]
    if not price then return false, Utils.t('duration_unavailable') end
    if not Utils.contains(Config.PaymentAccounts, account) then return false, Utils.t('invalid_account') end

    local category = Locations.Category(loc, vehicle.category)
    if category and not Bridge.HasLicense(src, category.license) then return false, Utils.t('need_license') end
    if #ofCid(s.cid) >= Config.Rentals.maxActive then return false, Utils.t('max_active', Config.Rentals.maxActive) end

    local now = os.time()
    if lastRent[src] and now - lastRent[src] < (Config.Rentals.spawnCooldown or 0) then return false, Utils.t('slow_down') end

    local point = freeSpawn(loc)
    if not point then return false, Utils.t('spawn_blocked') end

    local deposit = depositFor(vehicle)
    local total = price + deposit
    if Bridge.GetMoney(src, account) < total then return false, Utils.t('cant_afford', Utils.formatMoney(total)) end
    if not Bridge.RemoveMoney(src, account, total, 'vehicle-rental') then return false, Utils.t('cant_afford', Utils.formatMoney(total)) end
    lastRent[src] = now

    local plate = newPlate()
    local entity, netId = spawn(src, vehicle, point, plate)
    if not entity then
        Bridge.AddMoney(src, account, total, 'vehicle-rental-refund')
        return false, Utils.t('spawn_failed')
    end

    local r = {
        cid = s.cid, src = src, name = s.name, location = loc.id, locationLabel = loc.label, model = vehicle.model, label = vehicle.label,
        category = vehicle.category, categoryLabel = category and category.label or vehicle.category, plate = plate, durationId = duration.id,
        minutes = duration.minutes, price = price, deposit = deposit, account = account, paid = price, recharges = 0,
        startedAt = now, expiresAt = now + duration.minutes * 60, status = 'active', warned = {}, entity = entity, netId = netId,
    }
    local ok, id = pcall(DB.CreateRental, r)
    if not ok or not id then
        DeleteEntity(entity)
        Bridge.AddMoney(src, account, total, 'vehicle-rental-refund')
        print(('^1[%s] could not save rental: %s^7'):format(RESOURCE, tostring(id)))
        return false, Utils.t('error_generic')
    end
    r.id = id
    Rentals.active[id] = r
    Entity(entity).state:set('clRental', id, true)

    Bridge.GiveKeys(src, plate, entity)
    TriggerClientEvent(RESOURCE .. ':client:vehicleReady', src, netId, plate, Config.Rentals.fuel)

    if Config.Contract.item and Bridge.ItemExists(Config.Contract.item) then
        Bridge.AddItem(src, Config.Contract.item, {
            rentalId = id, contract = Utils.contractNo(id), plate = plate, vehicle = vehicle.label, renter = s.name,
            label = Utils.t('item_label', plate),
            description = Utils.t('item_description', s.name, vehicle.label, plate, Utils.contractNo(id)),
        })
    end

    push(s.cid)
    Utils.debug('rented', id, vehicle.model, plate, s.cid)
    return true, Utils.t('rented', vehicle.label, plate), { contract = Rentals.Contract(r) }
end, { rate = 1500 })

--[[ ─── Return ─────────────────────────────────────────────────────────── ]]

local function damageOf(entity)
    local body = GetVehicleBodyHealth(entity) or 1000.0
    local engine = math.max(0.0, GetVehicleEngineHealth(entity) or 1000.0)
    return math.floor(Utils.clamp((1000.0 - math.min(body, engine)) / 10.0, 0, 100) + 0.5)
end

Server.Register('returnVehicle', function(src, s, locId)
    local loc = Locations.Get(locId)
    if not loc then return false, Utils.t('no_rental_here') end
    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    if Locations.Distance(loc, coords) > loc.radius + 10.0 then return false, Utils.t('too_far') end

    local inside = GetVehiclePedIsIn(ped, false)
    local pick, wrongDesk
    for _, r in ipairs(ofCid(s.cid)) do
        local entity = entityOf(r)
        if entity and Locations.Distance(loc, GetEntityCoords(entity)) <= loc.radius then
            if Config.Return.anyLocation or r.location == loc.id then
                if not pick or entity == inside then pick = r end
            else
                wrongDesk = r
            end
        end
    end
    if not pick then
        if wrongDesk then return false, Utils.t('wrong_desk', wrongDesk.locationLabel) end
        return false, Utils.t('no_rental_here')
    end

    local r = pick
    local damage = damageOf(r.entity)
    local deduction = Config.Deposit.damageDeduction and math.floor(r.deposit * damage / 100) or 0
    local refund = r.deposit - deduction
    finish(r, 'returned', refund, damage)

    local message
    if r.deposit <= 0 then message = Utils.t('returned', r.label)
    elseif deduction > 0 then message = Utils.t('returned_damage', r.label, Utils.formatMoney(refund), damage, Utils.formatMoney(deduction))
    else message = Utils.t('returned_refund', r.label, Utils.formatMoney(refund)) end
    return true, message, { contract = Rentals.Contract(r) }
end, { rate = 1500 })

--[[ ─── My rentals / extend ────────────────────────────────────────────── ]]

local function atAnyDesk(src)
    local coords = GetEntityCoords(GetPlayerPed(src))
    for _, loc in pairs(Locations.list) do
        if loc.enabled and Locations.Distance(loc, coords) <= loc.radius + 10.0 then return true end
    end
    return false
end

--- Periods a rental can be extended by (priced by the desk it came from).
local function extendOptions(r)
    local loc = Locations.Get(r.location)
    local vehicle = loc and Locations.Vehicle(loc, r.model)
    local out = {}
    if not vehicle then return out end
    for _, d in ipairs(Config.Durations) do
        if vehicle.prices[d.id] then out[#out + 1] = { id = d.id, minutes = d.minutes, price = vehicle.prices[d.id] } end
    end
    return out
end

Server.Register('mine', function(src, s)
    local rentals = {}
    for _, r in ipairs(ofCid(s.cid)) do
        local row = public(r)
        row.extend = extendOptions(r)
        rentals[#rentals + 1] = row
    end
    local history = {}
    for _, row in ipairs(DB.PlayerHistory(s.cid, 8)) do
        history[#history + 1] = {
            id = row.id, contract = Utils.contractNo(row.id), label = row.label, plate = row.plate, status = row.status,
            locationLabel = row.location_label, paid = row.paid, refund = row.refund, startedAt = row.started_at, endedAt = row.ended_at,
        }
    end
    return {
        rentals = rentals, history = history, accounts = accounts(src), name = s.name, now = os.time(),
        canExtend = Config.Rentals.extendAnywhere or atAnyDesk(src),
    }
end)

Server.Register('extend', function(src, s, rentalId, durationId, account)
    local r = Rentals.active[tonumber(rentalId) or -1]
    if not r or r.cid ~= s.cid then return false, Utils.t('rental_not_found') end
    if not Config.Rentals.extendAnywhere and not atAnyDesk(src) then return false, Utils.t('extend_at_desk') end
    if not Utils.contains(Config.PaymentAccounts, account) then return false, Utils.t('invalid_account') end

    local duration, price = Utils.duration(durationId), nil
    for _, o in ipairs(extendOptions(r)) do
        if o.id == durationId then price = o.price end
    end
    if not duration or not price then return false, Utils.t('extend_unavailable') end
    if not Bridge.RemoveMoney(src, account, price, 'vehicle-rental-extension') then return false, Utils.t('cant_afford', Utils.formatMoney(price)) end

    r.expiresAt = math.max(r.expiresAt, os.time()) + duration.minutes * 60
    r.paid = r.paid + price
    r.warned = {}
    r.status = 'active'
    DB.UpdateRental(r)
    push(s.cid)
    return true, Utils.t('extended', r.label, Utils.durationLabel(duration.minutes), Utils.formatMoney(price))
end, { rate = 1000 })

Server.Register('locate', function(_, s, rentalId)
    local r = Rentals.active[tonumber(rentalId) or -1]
    if not r or r.cid ~= s.cid then return false, Utils.t('rental_not_found') end
    local entity = entityOf(r)
    if not entity then return false, Utils.t('rental_not_found') end
    local c = GetEntityCoords(entity)
    return true, Utils.t('waypoint_set'), { x = c.x, y = c.y }
end)

--[[ ─── Contract ───────────────────────────────────────────────────────── ]]

local function contractFor(src, s, rentalId)
    rentalId = tonumber(rentalId)
    local r = rentalId and Rentals.active[rentalId]
    if r then
        if r.cid == s.cid or Server.IsAdmin(src) or Bridge.HasContract(src, Config.Contract.item, r.id) then return Rentals.Contract(r) end
        return nil
    end
    local row = rentalId and DB.Rental(rentalId)
    if not row then return nil end
    if row.identifier == s.cid or Server.IsAdmin(src) or Bridge.HasContract(src, Config.Contract.item, row.id) then return Rentals.Contract(row) end
end

Server.Register('contract', function(src, s, rentalId)
    local contract = contractFor(src, s, rentalId)
    if not contract then return false, Utils.t('rental_not_found') end
    return contract
end)

-- qb-inventory / ESX: using the paper opens it (ox_inventory uses the client export instead)
Bridge.RegisterContractItem(Config.Contract.item, function(src, metadata)
    local s = Server.Session(src)
    if not s then return end
    local id = tonumber(metadata and metadata.rentalId)
    if not id then
        local latest = DB.LatestRental(s.cid)
        id = latest and latest.id
    end
    local contract = id and contractFor(src, s, id)
    if contract then TriggerClientEvent(RESOURCE .. ':client:contract', src, contract) end
end)

--[[ ─── Admin hooks (admin.lua) ─────────────────────────────────────────── ]]

function Rentals.AdminList()
    local out, now = {}, os.time()
    for _, r in pairs(Rentals.active) do
        local row = public(r)
        row.name = r.name
        row.online = r.src ~= nil
        row.remaining = r.expiresAt - now
        out[#out + 1] = row
    end
    table.sort(out, function(a, b) return a.expiresAt < b.expiresAt end)
    return out
end

--- Ends a rental from the admin panel: the vehicle is removed and the deposit refunded in full.
function Rentals.AdminEnd(id)
    local r = Rentals.active[tonumber(id) or -1]
    if not r then return false end
    local src = r.src
    finish(r, 'ended', r.deposit)
    if src then Bridge.Notify(src, Utils.t('ended_by_admin', r.label, r.plate), 'warning') end
    return true
end

--- A desk was deleted or its vehicle removed: nothing changes for running rentals, they keep their price.

AddEventHandler('onResourceStop', function(resource)
    if resource ~= RESOURCE then return end
    for _, r in pairs(Rentals.active) do
        local entity = entityOf(r)
        if entity then DeleteEntity(entity) end
    end
end)
