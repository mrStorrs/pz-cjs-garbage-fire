if isClient() then return end

require "Camping/SCampfireSystem"
require "Camping/SCampfireGlobalObject"
require "Camping/camping_fuel"
require "CJS_GarbageFire_Shared"

local originalLowerFirelvl = SCampfireSystem.lowerFirelvl
local originalFireRadius = SCampfireGlobalObject.fireRadius
local incineratorElapsedSeconds = 0

local function clampFuelMinutes(minutes)
    minutes = tonumber(minutes) or 0
    if minutes < CJSGarbageFire.minFuelMinutes then return CJSGarbageFire.minFuelMinutes end
    if minutes > CJSGarbageFire.maxFuelMinutes then return CJSGarbageFire.maxFuelMinutes end
    return minutes
end

local function maxGarbageFireFuelMinutes()
    local maxFuel = CJSGarbageFire.maxFuelMinutes
    if getCampingFuelMax then
        local sandboxMax = tonumber(getCampingFuelMax())
        if sandboxMax and sandboxMax > 0 then
            maxFuel = math.min(maxFuel, sandboxMax)
        end
    end

    return maxFuel
end

local function addGarbageFireFuel(campfire, minutes)
    minutes = tonumber(minutes) or 0
    if minutes <= 0 then return 0 end

    local currentFuel = tonumber(campfire.fuelAmt) or 0
    local room = maxGarbageFireFuelMinutes() - currentFuel
    if room <= 0 then return 0 end

    local addedFuel = math.min(minutes, room)
    campfire:addFuel(addedFuel)
    return addedFuel
end

local function trashFuelMinutes(item)
    local minutes = CJSGarbageFire.fuelMinutesForItem(item)
    if minutes > 0 then return minutes end

    local weight = tonumber(CJSGarbageFire.call(item, "getActualWeight") or CJSGarbageFire.call(item, "getWeight") or 0)
    if weight <= 0 then return 1 end

    return math.max(1, math.min(15, weight * 4))
end

local function trashContentsFuel(container)
    if not container then return 0 end

    local total = 0
    for index = 0, container:getItems():size() - 1 do
        local item = container:getItems():get(index)
        total = total + trashFuelMinutes(item)
    end

    return total
end

local function emptyTrashContents(trashCan)
    local container = trashCan and trashCan:getContainer()
    if not container then return 0 end

    local items = container:getItems()
    local count = items:size()
    if count <= 0 then return 0 end

    if isServer() then
        sendRemoveItemsFromContainer(container, items)
    end
    while items:size() > 0 do
        container:DoRemoveItem(items:get(0))
    end
    container:clear()
    CJSGarbageFire.call(container, "setDrawDirty", true)
    if trashCan:getOverlaySprite() then
        ItemPicker.updateOverlaySprite(trashCan)
    end
    return count
end

local function burnTrashContents(trashCan, campfire)
    local container = trashCan and trashCan:getContainer()
    if not container or container:getItems():size() <= 0 then return 0, 0 end

    local fuelMinutes = trashContentsFuel(container)
    local itemCount = emptyTrashContents(trashCan)
    local addedFuel = addGarbageFireFuel(campfire, fuelMinutes)
    return itemCount, addedFuel
end

local function findTrashCan(square, objectIndex)
    if not square then return nil end

    local objects = square:getObjects()
    objectIndex = tonumber(objectIndex)

    if objectIndex and objectIndex >= 0 and objectIndex < objects:size() then
        local object = objects:get(objectIndex)
        if CJSGarbageFire.isTrashCanObject(object) then return object end
    end

    for index = objects:size() - 1, 0, -1 do
        local object = objects:get(index)
        if CJSGarbageFire.isTrashCanObject(object) then return object end
    end

    return nil
end

local function tagCampfire(campfire, trashCan)
    local isoObject = campfire and campfire:getIsoObject()
    if not isoObject then return end

    local modData = isoObject:getModData()
    modData[CJSGarbageFire.modDataKey] = true
    modData.CJS_GarbageFireTrashName = CJSGarbageFire.objectDisplayName(trashCan)
    modData.CJS_GarbageFireTrashObjectIndex = trashCan:getObjectIndex()
    isoObject:transmitModData()
end

local function trashCanForCampfire(campfire)
    if not campfire then return nil end

    local isoObject = campfire:getIsoObject()
    local modData = isoObject and isoObject:getModData()
    return findTrashCan(campfire:getSquare(), modData and modData.CJS_GarbageFireTrashObjectIndex)
end

local function startGarbageFire(playerObj, args)
    if not playerObj or not args then return end

    local square = getCell():getGridSquare(args.x, args.y, args.z)
    if not square then return end
    if SCampfireSystem.instance:getLuaObjectOnSquare(square) then return end

    local trashCan = findTrashCan(square, args.objectIndex)
    if not trashCan then return end

    local dx = math.abs(playerObj:getX() - (square:getX() + 0.5))
    local dy = math.abs(playerObj:getY() - (square:getY() + 0.5))
    if dx > 2 or dy > 2 or playerObj:getZ() ~= square:getZ() then return end

    local trashFuel = trashContentsFuel(trashCan:getContainer())
    local totalFuel = clampFuelMinutes((tonumber(args.tinderFuelMinutes) or 0) + trashFuel)
    local campfire = SCampfireSystem.instance:addCampfire(square)
    if not campfire then return end

    tagCampfire(campfire, trashCan)
    addGarbageFireFuel(campfire, totalFuel)
    campfire:lightFire()
    emptyTrashContents(trashCan)
end

local function onClientCommand(module, command, playerObj, args)
    if module ~= CJSGarbageFire.commandModule then return end

    if command == "startFire" then
        startGarbageFire(playerObj, args)
    end
end

function SCampfireSystem:lowerFirelvl()
    local muted = {}

    for index = 1, self:getLuaObjectCount() do
        local campfire = self:getLuaObjectByIndex(index)
        if CJSGarbageFire.isGarbageCampfire(campfire) and campfire.isLit then
            muted[#muted + 1] = campfire
            campfire.isLit = false
        end
    end

    originalLowerFirelvl(self)

    for _, campfire in ipairs(muted) do
        campfire.isLit = true
    end
end

function SCampfireGlobalObject:fireRadius()
    if CJSGarbageFire.isGarbageCampfire(self) then
        if not self.isLit then return 0 end
        return math.max(2, math.min(4, 2 + (self.fuelAmt / 60)))
    end

    return originalFireRadius(self)
end

local function cleanupExpiredGarbageFires()
    local system = SCampfireSystem.instance
    if not system then return end

    for index = system:getLuaObjectCount(), 1, -1 do
        local campfire = system:getLuaObjectByIndex(index)
        if CJSGarbageFire.isGarbageCampfire(campfire) and (not campfire.isLit or campfire.fuelAmt <= 0) then
            system:removeCampfire(campfire)
        end
    end
end

local function sweepBurningGarbageFires()
    local system = SCampfireSystem.instance
    if not system then return end

    for index = system:getLuaObjectCount(), 1, -1 do
        local campfire = system:getLuaObjectByIndex(index)
        if CJSGarbageFire.isGarbageCampfire(campfire) and campfire.isLit and campfire.fuelAmt > 0 then
            burnTrashContents(trashCanForCampfire(campfire), campfire)
        end
    end
end

local function incineratorTick()
    local deltaSeconds = getGameTime():getRealworldSecondsSinceLastUpdate() or 0
    if deltaSeconds <= 0 then return end

    incineratorElapsedSeconds = incineratorElapsedSeconds + deltaSeconds
    local scanSeconds = CJSGarbageFire.scanIntervalSeconds()
    if incineratorElapsedSeconds < scanSeconds then return end

    incineratorElapsedSeconds = 0
    sweepBurningGarbageFires()
end

Events.OnClientCommand.Add(onClientCommand)
Events.OnTick.Add(incineratorTick)
Events.EveryOneMinute.Add(cleanupExpiredGarbageFires)
print("[cjsGarbageFire] Loaded server " .. CJSGarbageFire.version)
