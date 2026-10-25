--[[ ═══════════════════════════════════════════════════════════════════════
     TARGET BRIDGE
     The script talks to `Target`, which forwards to ox_target or qb-target
     (Config.Target = 'auto' picks whichever is running, ox_target first).
     Options are written in the ox_target format; for qb-target they are
     converted here. Not escrowed — add another target system if you need to.
     ═══════════════════════════════════════════════════════════════════════ ]]

Target = {}

local RESOURCE = GetCurrentResourceName()
local function started(name) return GetResourceState(name) == 'started' end

local system = Config.Target ~= 'auto' and Config.Target
    or (started('ox_target') and 'ox_target') or (started('qb-target') and 'qb-target') or 'ox_target'
Target.system = system

if system == 'ox_target' then
    function Target.addLocalEntity(entity, options) return exports.ox_target:addLocalEntity(entity, options) end
    function Target.removeLocalEntity(entity, names) return exports.ox_target:removeLocalEntity(entity, names) end
    function Target.addSphereZone(data) return exports.ox_target:addSphereZone(data) end
    function Target.removeZone(id) return exports.ox_target:removeZone(id) end
    function Target.addGlobalVehicle(options) return exports.ox_target:addGlobalVehicle(options) end
    function Target.removeGlobalVehicle(names) return exports.ox_target:removeGlobalVehicle(names) end
    function Target.addGlobalPed(options) return exports.ox_target:addGlobalPed(options) end
    function Target.removeGlobalPed(names) return exports.ox_target:removeGlobalPed(names) end
    function Target.addModel(models, options) return exports.ox_target:addModel(models, options) end
    function Target.removeModel(models, names) return exports.ox_target:removeModel(models, names) end
    return
end

--[[ ─── qb-target ──────────────────────────────────────────────────────── ]]

local qb = exports['qb-target']

local function list(options)
    if options.label then return { options } end   -- a single option
    return options
end

local function entityCoords(entity)
    if entity and entity ~= 0 and DoesEntityExist(entity) then return GetEntityCoords(entity) end
    return GetEntityCoords(cache.ped)
end

--- ox_target options -> qb-target options. qb-target keys options by label, so options that share a label
--- are merged into one: it shows when any of them can be used, and runs the first one that can.
---@return table qbOptions, number maxDistance, table nameToLabel
local function convert(options)
    local byLabel, order, names, maxDistance = {}, {}, {}, 0

    for _, option in ipairs(list(options)) do
        local distance = option.distance or 2.0
        maxDistance = math.max(maxDistance, distance)
        if option.name then names[option.name] = option.label end

        local variant = {
            allowed = function(entity, dist)
                if option.groups and not Bridge.HasGroup(option.groups) then return false end
                if dist and dist > distance then return false end
                if option.canInteract then
                    return option.canInteract(entity, dist, entityCoords(entity), option.name) and true or false
                end
                return true
            end,
            run = function(entity, dist)
                if option.onSelect then
                    option.onSelect({ entity = entity, coords = entityCoords(entity), distance = dist, name = option.name })
                end
            end,
        }

        local entry = byLabel[option.label]
        if entry then
            entry.variants[#entry.variants + 1] = variant
            entry.distance = math.max(entry.distance, distance)
        else
            entry = { label = option.label, icon = option.icon, distance = distance, variants = { variant } }
            byLabel[option.label] = entry
            order[#order + 1] = entry
        end
    end

    local converted = {}
    for _, entry in ipairs(order) do
        converted[#converted + 1] = {
            label = entry.label,
            icon = entry.icon,
            distance = entry.distance,
            canInteract = function(entity, dist)
                for _, variant in ipairs(entry.variants) do
                    if variant.allowed(entity, dist) then return true end
                end
                return false
            end,
            action = function(entity)
                local dist = #(GetEntityCoords(cache.ped) - entityCoords(entity))
                for _, variant in ipairs(entry.variants) do
                    if variant.allowed(entity, dist) then return variant.run(entity, dist) end
                end
            end,
        }
    end
    return converted, maxDistance, names
end

local function labelsFor(map, names)
    if not names then return nil end
    local labels = {}
    for _, name in ipairs(type(names) == 'table' and names or { names }) do
        labels[#labels + 1] = map[name] or name
    end
    return labels
end

local entityNames, globalNames, zones, zoneCount = {}, {}, {}, 0
local globalVehicle, globalPed = {}, {}   -- labels added to every vehicle / ped

function Target.addLocalEntity(entity, options)
    local converted, distance, names = convert(options)
    entityNames[entity] = entityNames[entity] or {}
    for name, label in pairs(names) do entityNames[entity][name] = label end
    qb:AddTargetEntity(entity, { options = converted, distance = distance })
end

function Target.removeLocalEntity(entity, names)
    qb:RemoveTargetEntity(entity, labelsFor(entityNames[entity] or {}, names))
    if not names then entityNames[entity] = nil end
end

function Target.addSphereZone(data)
    zoneCount = zoneCount + 1
    local name = data.name or ('%s:zone:%d'):format(RESOURCE, zoneCount)
    local converted, distance = convert(data.options)
    qb:AddCircleZone(name, data.coords, data.radius or 1.0, { name = name, debugPoly = data.debug or false, useZ = true },
        { options = converted, distance = distance })
    zones[name] = true
    return name
end

function Target.removeZone(id)
    zones[id] = nil
    qb:RemoveZone(id)
end

function Target.addGlobalVehicle(options)
    local converted, distance, names = convert(options)
    for name, label in pairs(names) do globalNames[name] = label globalVehicle[label] = true end
    qb:AddGlobalVehicle({ options = converted, distance = distance })
end

function Target.removeGlobalVehicle(names)
    qb:RemoveGlobalVehicle(labelsFor(globalNames, names))
end

function Target.addGlobalPed(options)
    local converted, distance, names = convert(options)
    for name, label in pairs(names) do globalNames[name] = label globalPed[label] = true end
    qb:AddGlobalPed({ options = converted, distance = distance })
end

function Target.removeGlobalPed(names)
    qb:RemoveGlobalPed(labelsFor(globalNames, names))
end

local modelLabels = {}   -- model -> labels added to it

function Target.addModel(models, options)
    local converted, distance, names = convert(options)
    for _, model in ipairs(type(models) == 'table' and models or { models }) do
        modelLabels[model] = modelLabels[model] or {}
        for name, label in pairs(names) do globalNames[name] = label modelLabels[model][label] = true end
    end
    qb:AddTargetModel(models, { options = converted, distance = distance })
end

function Target.removeModel(models, names)
    local labels = names and labelsFor(globalNames, names)
    for _, model in ipairs(type(models) == 'table' and models or { models }) do
        local list = labels
        if not list then
            list = {}
            for label in pairs(modelLabels[model] or {}) do list[#list + 1] = label end
            modelLabels[model] = nil
        end
        if #list > 0 then qb:RemoveTargetModel(model, list) end
    end
end

-- qb-target keeps options after the resource that added them stops: remove everything this resource added
AddEventHandler('onResourceStop', function(resource)
    if resource ~= RESOURCE then return end
    for id in pairs(zones) do pcall(qb.RemoveZone, qb, id) end
    for entity in pairs(entityNames) do pcall(qb.RemoveTargetEntity, qb, entity) end
    local vehicles, peds = {}, {}
    for label in pairs(globalVehicle) do vehicles[#vehicles + 1] = label end
    for label in pairs(globalPed) do peds[#peds + 1] = label end
    if #vehicles > 0 then pcall(qb.RemoveGlobalVehicle, qb, vehicles) end
    if #peds > 0 then pcall(qb.RemoveGlobalPed, qb, peds) end
end)
