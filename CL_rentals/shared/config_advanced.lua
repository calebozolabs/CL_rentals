--[[ ═══════════════════════════════════════════════════════════════════════
     CL RENTALS — ADVANCED CONFIG
     Defaults for new desks, and the desk created on first start. Everything
     about a desk can be changed in-game with /rentaladmin.
     ═══════════════════════════════════════════════════════════════════════ ]]

--- Defaults for a desk created in-game.
Config.NewLocation = {
    ped  = 'a_m_y_business_03',
    blip = { enabled = true, sprite = 225, color = 5, scale = 0.75 },
}

Config.PedScenario = 'WORLD_HUMAN_CLIPBOARD'   -- what the rental agent does (false = stand still)
Config.PedDistance = 60.0                      -- the agent is created when you get this close

--- Icons a category can use in the editor (the UI draws them).
Config.CategoryIcons = { 'car', 'sport', 'suv', 'van', 'truck', 'bike', 'scooter', 'cycle', 'boat', 'heli', 'plane', 'star' }

--[[ Licence types a category can require. Key = what the editor stores.
     qb / qbx: the key of PlayerData.metadata.licences
     esx:      the `type` in the user_licenses table ]]
Config.Licenses = {
    driver = { qb = 'driver', esx = 'drive' },
    bike   = { qb = 'driver', esx = 'drive_bike' },
    truck  = { qb = 'driver', esx = 'drive_truck' },
    boat   = { qb = 'boat',   esx = 'boat' },
    pilot  = { qb = 'pilot',  esx = 'aircraft' },
}

--[[ ─── Desk created on first start ───────────────────────────────────────
     Only used when the database has no desks yet. Afterwards edit it in-game.
     Coordinates are by Legion Square; move the agent and spawn points with the editor if
     they don't suit your map. Prices are per period id from Config.Durations. ]]

Config.DefaultLocations = {
    {
        id = 'legion',
        label = 'Legion Square Rentals',
        enabled = true,
        ped = { model = 'a_m_y_business_03', coords = { x = 109.97, y = -1088.61, z = 29.30, w = 345.64 } },
        blip = { enabled = true, sprite = 225, color = 5, scale = 0.75 },
        radius = 30.0,
        spawns = {
            { x = 111.42, y = -1081.24, z = 29.19, w = 340.0 },
        },
        categories = {
            { id = 'economy', label = 'Economy', icon = 'car' },
            { id = 'sport',   label = 'Sport',   icon = 'sport' },
            { id = 'bikes',   label = 'Motorcycles', icon = 'bike', license = 'bike' },
            { id = 'utility', label = 'Utility', icon = 'van' },
        },
        vehicles = {
            { model = 'panto',   label = 'Benefactor Panto',  type = 'automobile', category = 'economy', prices = { ['30m'] = 150, ['1h'] = 250, ['3h'] = 600 } },
            { model = 'asbo',    label = 'Maxwell Asbo',      type = 'automobile', category = 'economy', prices = { ['30m'] = 175, ['1h'] = 300, ['3h'] = 700 } },
            { model = 'blista',  label = 'Dinka Blista',      type = 'automobile', category = 'economy', prices = { ['30m'] = 200, ['1h'] = 350, ['3h'] = 800 } },
            { model = 'sultan',  label = 'Karin Sultan',      type = 'automobile', category = 'sport',   prices = { ['30m'] = 450, ['1h'] = 800, ['3h'] = 1900 }, deposit = 750 },
            { model = 'elegy2',  label = 'Annis Elegy RH8',   type = 'automobile', category = 'sport',   prices = { ['30m'] = 600, ['1h'] = 1050, ['3h'] = 2500 }, deposit = 1000 },
            { model = 'faggio',  label = 'Pegassi Faggio',    type = 'bike',       category = 'bikes',   prices = { ['30m'] = 100, ['1h'] = 175, ['3h'] = 400 } },
            { model = 'bati',    label = 'Pegassi Bati 801',  type = 'bike',       category = 'bikes',   prices = { ['30m'] = 350, ['1h'] = 600, ['3h'] = 1400 }, deposit = 500 },
            { model = 'bison',   label = 'Bravado Bison',     type = 'automobile', category = 'utility', prices = { ['30m'] = 250, ['1h'] = 450, ['3h'] = 1050 } },
            { model = 'speedo',  label = 'Vapid Speedo',      type = 'automobile', category = 'utility', prices = { ['30m'] = 275, ['1h'] = 475, ['3h'] = 1100 } },
        },
    },
}

Config.Security = {
    rateLimitMs  = 350,        -- min time between two requests of the same kind from one player
    deskDistance = 12.0,       -- how close to the agent a player must be to rent
}
