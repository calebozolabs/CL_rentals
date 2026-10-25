Config = {}

--[[ ═══════════════════════════════════════════════════════════════════════
     CL RENTALS — MAIN CONFIG
     Rental desks (location, ped, spawn points, categories, vehicles and
     prices) are built in-game with /rentaladmin — no config edits needed.
     Most values in this file can also be changed in-game in
     /rentaladmin → Settings; those edits are saved to the database and
     win over this file until you press "Reset".

       config_advanced.lua   default desk, icons, blips, licence types, peds
       theme.lua             colours
       locales/en.lua        every text / translation
     ═══════════════════════════════════════════════════════════════════════ ]]


--[[ ─── 1. SERVER SETUP ───────────────────────────────────────────────────
     'auto' detects what your server runs. Only change these if detection picks the wrong one. ]]

Config.Framework   = 'auto'    -- 'auto' | 'qbx' | 'qb' | 'esx'
Config.Inventory   = 'auto'    -- 'auto' | 'ox_inventory' | 'qb-inventory' | 'esx'
Config.Target      = 'auto'    -- 'auto' | 'ox_target' | 'qb-target'   (only used when Config.Interaction = 'target')
Config.VehicleKeys = 'auto'    -- 'auto' | 'p_vehiclekeys' | 'qbx_vehiclekeys' | 'qb-vehiclekeys' | 'Renewed-Vehiclekeys' | 'wasabi_carlock' | 'qs-vehiclekeys' | 'none'
Config.Fuel        = 'auto'    -- 'auto' | 'ox_fuel' | 'LegacyFuel' | 'cdn-fuel' | 'ps-fuel' | 'lj-fuel' | 'CL_fuel' | 'okokGasStation' | 'lc_fuel' | 'Renewed-Fuel' | 'native'

Config.Locale = 'en'           -- locales/<code>.lua

Config.Notify = {
    system   = 'cl',           -- 'cl' (built-in notifications) | 'ox_lib' | 'qb' | 'esx'
    position = 'top-right',    -- 'cl' only: top-right | top-left | top | bottom | bottom-right | bottom-left | center-right
    duration = 6000,           -- ms
}

Config.Debug = false           -- prints extra information to the F8 / server console


--[[ ─── 2. INTERACTION ────────────────────────────────────────────────────
     'target'  third-eye the rental agent (ox_target / qb-target)
     'textui'  walk up to the agent and press [E]
     Returning a rental always works by driving it up to a desk and pressing [E]. ]]

Config.Interaction = 'target'  -- 'target' | 'textui'
Config.InteractKey = 38        -- [E]  https://docs.fivem.net/docs/game-references/controls/

Config.Commands = {
    rentals = 'rentals',       -- players: your active rentals and contracts (set to false to disable)
}


--[[ ─── 3. MONEY ────────────────────────────────────────────────────────── ]]

Config.CurrencySymbol  = '$'
Config.PaymentAccounts = { 'bank', 'cash' }   -- accounts players can pay with, in the order they are offered


--[[ ─── 4. ADMIN ──────────────────────────────────────────────────────────
     In server.cfg:   add_ace group.admin cl.admin allow ]]

Config.Admin = {
    ace     = 'cl.admin',      -- builds / edits rental desks, ends rentals, edits settings
    command = 'rentaladmin',
}


--[[ ─── 5. RENTAL PERIODS ─────────────────────────────────────────────────
     The rental options players choose from. Every vehicle gets its own price for
     each period in the in-game editor. Leave a vehicle's price empty to not offer
     that period for it. `id` is stored with prices: don't rename an id after
     you've priced vehicles with it. ]]

Config.Durations = {
    { id = '30m', minutes = 30 },
    { id = '1h',  minutes = 60 },
    { id = '3h',  minutes = 180 },
}


--[[ ─── 6. RENTALS (also editable in-game) ──────────────────────────────── ]]

Config.Rentals = {
    maxActive       = 1,       -- rentals one character can have at the same time
    platePrefix     = 'RENT',  -- plates look like RENT4821 (prefix + digits, 8 characters)
    spawnCooldown   = 5,       -- seconds between rentals per player (anti-spam)
    warpIntoVehicle = true,    -- put the renter in the driver seat
    fuel            = 100,     -- fuel level the vehicle is handed over with
    extendAnywhere  = true,    -- true: extend from /rentals anywhere · false: only at a rental desk
}

Config.Deposit = {
    enabled         = true,
    amount          = 250,     -- default refundable deposit (a vehicle can override it in the editor)
    damageDeduction = true,    -- deduct the vehicle's damage % from the deposit on return
}


--[[ ─── 7. WHEN THE TIME RUNS OUT (also editable in-game) ──────────────────
     The renter is warned before the end of the rental (`warnings`, minutes before).

     'recharge'   the rental renews itself: the renter is charged the price of the same
                  period again and gets more time. When they can't pay, are offline, or
                  `maxRecharges` is reached, the vehicle is repossessed.
     'repossess'  the renter has `grace` minutes to bring it back, then the vehicle is
                  taken and the deposit is kept. ]]

Config.Expiry = {
    mode         = 'recharge', -- 'recharge' | 'repossess'
    warnings     = { 10, 2 },  -- minutes before the end
    maxRecharges = 3,          -- 'recharge': times a rental renews itself (0 = no limit)
    grace        = 5,          -- 'repossess': minutes after the end before the vehicle is taken
}


--[[ ─── 8. RETURNS ───────────────────────────────────────────────────────── ]]

Config.Return = {
    anyLocation   = true,      -- true: return at any rental desk · false: only where it was rented
    defaultRadius = 30.0,      -- return zone around a new desk (each desk has its own in the editor)
}


--[[ ─── 9. RENTAL CONTRACT ────────────────────────────────────────────────
     The renter always gets the contract on screen and can open it again with /rentals.
     Set `item` to also hand out a physical contract (needs the item added to your
     inventory — see install/README_ITEMS.md). Set to false to disable the item. ]]

Config.Contract = {
    item           = 'rental_contract',
    removeOnReturn = true,     -- take the paper back when the vehicle is returned / repossessed
}

-- A server restart removes every rental vehicle. true = refund those deposits the next time the renter logs in.
Config.RefundOnRestart = true

-- Vehicle pictures in the UI ('%s' = model name). Vehicles without a picture show an icon.
Config.VehicleImagePath = 'https://docs.fivem.net/vehicles/%s.webp'
