--[[ ═══════════════════════════════════════════════════════════════════════
     ADMINISTRATION  (/rentaladmin)
     Needs Config.Admin.ace:   add_ace group.admin cl.admin allow
     Build and edit desks, see and end live rentals, browse the history and
     change settings. Every change is printed to the server console.
     ═══════════════════════════════════════════════════════════════════════ ]]

local RESOURCE = GetCurrentResourceName()

local function log(src, action, target)
    local name = src == 0 and 'Console' or (Sessions[src] and Sessions[src].name or GetPlayerName(src))
    print(('^3[%s] admin %s by %s → %s^7'):format(RESOURCE, action, tostring(name), tostring(target)))
end

local function historyRow(row)
    return {
        id = row.id, contract = Utils.contractNo(row.id), name = row.name, label = row.label, model = row.model, plate = row.plate,
        locationLabel = row.location_label, minutes = row.minutes, paid = row.paid, deposit = row.deposit, refund = row.refund,
        recharges = row.recharges, damage = row.damage, status = row.status, startedAt = row.started_at, endedAt = row.ended_at,
    }
end

Server.Register('adminData', function()
    local history = {}
    for _, row in ipairs(DB.History(60)) do history[#history + 1] = historyRow(row) end
    local counts = {}
    for _, r in pairs(Rentals.active) do counts[r.location] = (counts[r.location] or 0) + 1 end
    return {
        locations = Locations.Public(), activeAt = counts, active = Rentals.AdminList(), history = history,
        stats = DB.Stats(), settings = Settings.Rows(), now = os.time(),
        icons = Config.CategoryIcons, licenses = (function()
            local out = {}
            for key in pairs(Config.Licenses) do out[#out + 1] = key end
            table.sort(out)
            return out
        end)(),
        defaults = { ped = Config.NewLocation.ped, blip = Config.NewLocation.blip, radius = Config.Return.defaultRadius, deposit = Config.Deposit.amount },
    }
end, { admin = true, rate = 600 })

Server.Register('adminSaveLocation', function(src, _, raw, existingId)
    if existingId ~= nil and not Locations.Get(existingId) then return false, Utils.t('invalid_location') end
    local loc, err = Locations.Validate(raw, existingId)
    if not loc then return false, err end
    Locations.Save(loc)
    log(src, existingId and 'edited desk' or 'created desk', loc.id)
    return true, Utils.t('location_saved', loc.label), { id = loc.id, locations = Locations.Public() }
end, { admin = true, rate = 800 })

Server.Register('adminDeleteLocation', function(src, _, id)
    local loc = Locations.Get(id)
    if not loc then return false, Utils.t('invalid_location') end
    Locations.Delete(id)
    log(src, 'deleted desk', id)
    return true, Utils.t('location_deleted', loc.label), { locations = Locations.Public() }
end, { admin = true })

Server.Register('adminEndRental', function(src, _, id)
    if not Rentals.AdminEnd(id) then return false, Utils.t('rental_not_found') end
    log(src, 'ended rental', id)
    return true, Utils.t('rental_ended')
end, { admin = true })

Server.Register('adminSetting', function(src, s, key, value)
    local ok, err = Settings.Set(key, value, s.name)
    if not ok then return false, err end
    log(src, 'setting ' .. tostring(key), json.encode(value))
    return true, Utils.t('setting_saved'), { settings = Settings.Rows() }
end, { admin = true, rate = 250 })

Server.Register('adminResetSetting', function(src, _, key)
    if not Settings.Reset(key) then return false, Utils.t('setting_unknown') end
    log(src, 'reset setting', key)
    return true, Utils.t('setting_reset'), { settings = Settings.Rows() }
end, { admin = true, rate = 250 })

--[[ ─── Console ──────────────────────────────────────────────────────────
     rentaladmin debug        toggle debug logging
     rentaladmin end <id>     end a rental (deposit refunded) ]]

RegisterCommand(Config.Admin.command, function(src, args)
    if src ~= 0 then return end   -- in game the command is handled by the client
    local action = args[1]
    if action == 'debug' then
        Config.Debug = not Config.Debug
        print(('[%s] debug %s'):format(RESOURCE, Config.Debug and 'on' or 'off'))
    elseif action == 'end' and args[2] then
        print(('[%s] %s'):format(RESOURCE, Rentals.AdminEnd(args[2]) and 'rental ended' or 'no active rental with that id'))
    else
        print(('[%s] %d active rental(s). Usage: %s debug | %s end <id>'):format(RESOURCE, Utils.count(Rentals.active), Config.Admin.command, Config.Admin.command))
    end
end, true)
