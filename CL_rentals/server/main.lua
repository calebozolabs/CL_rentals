--[[ ═══════════════════════════════════════════════════════════════════════
     SERVER CORE
     Sessions, the rate-limited callback registry, startup and the player
     lifecycle. Every client request goes through Server.Register.
     ═══════════════════════════════════════════════════════════════════════ ]]

Server = {}
Sessions = {}    -- src -> { cid, name }

local RESOURCE = GetCurrentResourceName()
local ready = false
Server.Ready = function() return ready end

function Server.IsAdmin(src)
    if src == 0 then return true end
    return IsPlayerAceAllowed(src, Config.Admin.ace) and true or false
end

--[[ ─── Rate limiting ──────────────────────────────────────────────────── ]]

local lastCall = {}

local function limited(src, name, ms)
    local now = GetGameTimer()
    local calls = lastCall[src]
    if not calls then calls = {} lastCall[src] = calls end
    if calls[name] and now - calls[name] < (ms or Config.Security.rateLimitMs) then return true end
    calls[name] = now
    return false
end

--[[ ─── Callback registry ────────────────────────────────────────────────
     Handlers get (src, session, ...) and return ok, message, data — or a table. ]]

function Server.Register(name, handler, opts)
    opts = opts or {}
    lib.callback.register(RESOURCE .. ':server:' .. name, function(src, ...)
        if not ready then return false, Utils.t('not_ready') end
        if limited(src, name, opts.rate) then return false, Utils.t('slow_down') end
        local session = Server.Session(src)
        if not session then return false, Utils.t('not_ready') end
        if opts.admin and not Server.IsAdmin(src) then return false, Utils.t('no_permission') end
        local results = table.pack(pcall(handler, src, session, ...))
        if not results[1] then
            print(('^1[%s] %s failed: %s^7'):format(RESOURCE, name, results[2]))
            return false, Utils.t('error_generic')
        end
        return table.unpack(results, 2, results.n)
    end)
end

--[[ ─── Sessions ───────────────────────────────────────────────────────── ]]

--- Deposits owed while the renter was offline (a server restart, or a return / admin end while
--- logged off) are paid out on the next login.
local function payRefunds(src, cid)
    for _, row in ipairs(DB.RefundsDue(cid)) do
        local account = Utils.contains(Config.PaymentAccounts, row.account) and row.account or Config.PaymentAccounts[1]
        if Bridge.AddMoney(src, account, row.refund_due, 'rental-deposit-refund') then
            DB.RefundPaid(row.id, row.refund_due)
            Bridge.Notify(src, Utils.t('restart_refund', Utils.formatMoney(row.refund_due), row.label, row.plate), 'success')
        end
    end
end

function Server.Session(src)
    local s = Sessions[src]
    if s then return s end
    local cid = Bridge.GetIdentifier(src)
    if not cid then return nil end
    s = { cid = cid, name = Bridge.GetName(src) }
    Sessions[src] = s
    if ready then CreateThread(function() payRefunds(src, cid) end) end
    Rentals.Attach(src, cid)
    return s
end

function Server.SourceOf(cid)
    for src, s in pairs(Sessions) do
        if s.cid == cid then return src end
    end
    return Bridge.GetSourceByIdentifier(cid)
end

local function dropSession(src)
    if not Sessions[src] then return end
    Rentals.Detach(src)
    Sessions[src] = nil
    lastCall[src] = nil
end

Bridge.OnPlayerUnload(dropSession)
AddEventHandler('playerDropped', function() dropSession(source) end)

Bridge.OnPlayerLoaded(function(src)
    if not src then return end
    dropSession(src)   -- a character switch: start fresh
    SetTimeout(1500, function()
        if Server.Session(src) then TriggerClientEvent(RESOURCE .. ':client:ready', src) end
    end)
end)

--[[ ─── Bootstrap (client start) ───────────────────────────────────────── ]]

lib.callback.register(RESOURCE .. ':server:bootstrap', function(src)
    if not ready then return nil end
    local session = Server.Session(src)
    if not session then return nil end
    return {
        admin = Server.IsAdmin(src),
        locations = Locations.Public(),
        rentals = Rentals.ListFor(session.cid),
        now = os.time(),
    }
end)

--[[ ─── Startup ────────────────────────────────────────────────────────── ]]

MySQL.ready(function()
    DB.Init()
    Settings.Load()
    local orphans = DB.CloseOrphans(Config.RefundOnRestart)
    if orphans > 0 then print(('^3[%s] closed %d rental(s) left open by a restart^7'):format(RESOURCE, orphans)) end
    Locations.Load()
    ready = true
    Rentals.Start()

    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        if Server.Session(src) then TriggerClientEvent(RESOURCE .. ':client:ready', src) end
    end
    print(('^2[%s]^7 ready: ^5%d^7 rental desk(s)'):format(RESOURCE, Utils.count(Locations.list)))
end)
