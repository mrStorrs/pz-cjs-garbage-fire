require "Camping/ISUI/ISCampingMenu"
require "Camping/TimedActions/ISPutOutCampfireAction"
require "CJS_GarbageFire_Shared"
require "TimedActions/CJSBurnTrashAction"

local function squareKey(square)
    if not square then return nil end
    return tostring(square:getX()) .. ":" .. tostring(square:getY()) .. ":" .. tostring(square:getZ())
end

local function scanSquareForTrashCan(square)
    if not square then return nil end

    local objects = square:getObjects()
    for index = objects:size() - 1, 0, -1 do
        local object = objects:get(index)
        if CJSGarbageFire.isTrashCanObject(object) then
            return object
        end
    end

    return nil
end

local function findTrashCan(worldobjects)
    local checked = {}

    local function scan(square)
        local key = squareKey(square)
        if not key or checked[key] then return nil end
        checked[key] = true
        return scanSquareForTrashCan(square)
    end

    for _, object in ipairs(worldobjects) do
        local trashCan = scan(object and object:getSquare())
        if trashCan then return trashCan end
    end

    local fetch = ISWorldObjectContextMenu.fetchVars
    local clickedSquare = fetch and fetch.clickedSquare
    local trashCan = scan(clickedSquare)
    if trashCan then return trashCan end

    if clickedSquare then
        for dx = -1, 1 do
            for dy = -1, 1 do
                trashCan = scan(getCell():getGridSquare(clickedSquare:getX() + dx, clickedSquare:getY() + dy, clickedSquare:getZ()))
                if trashCan then return trashCan end
            end
        end
    end

    return nil
end

local function firstStarter(playerObj)
    return playerObj:getInventory():getFirstEvalRecurse(CJSGarbageFire.isStarterItem)
end

local function firstTinder(playerObj)
    return playerObj:getInventory():getFirstEvalRecurse(CJSGarbageFire.isRagItem) or
        playerObj:getInventory():getFirstEvalRecurse(CJSGarbageFire.isRagOrClothing)
end

local function tooltip(option, name, description)
    local tip = ISWorldObjectContextMenu.addToolTip()
    tip:setName(name)
    tip.description = description
    option.toolTip = tip
end

local function removeVanillaCampfireOptions(context)
    if not context.removeOptionByName then return end

    local optionNames = {
        getText("ContextMenu_CampfireInfo"),
        campingText and campingText.addFuel,
        campingText and campingText.lightCampfire,
        campingText and campingText.putOutCampfire,
        campingText and campingText.removeCampfire,
    }

    for _, name in ipairs(optionNames) do
        if name then context:removeOptionByName(name) end
    end
end

local function putOutTrashFire(playerObj, campfire)
    if not campfire or not campfire:getSquare() then return end
    if ISCampingMenu.walkToCampfire(playerObj, campfire:getSquare()) then
        ISTimedActionQueue.add(ISPutOutCampfireAction:new(playerObj, campfire, 60))
    end
end

local function burnTrash(playerObj, object, starter, tinder)
    if not object or not starter or not tinder then return end

    ISInventoryPaneContextMenu.transferIfNeeded(playerObj, starter)
    ISInventoryPaneContextMenu.transferIfNeeded(playerObj, tinder)
    if not luautils.walkAdj(playerObj, object:getSquare(), true) then return end

    if playerObj:isEquipped(tinder) then
        ISTimedActionQueue.add(ISUnequipAction:new(playerObj, tinder, 50))
    end

    ISTimedActionQueue.add(CJSBurnTrashAction:new(playerObj, object, starter, tinder, 120))
end

local function onFillWorldObjectContextMenu(player, context, worldobjects, test)
    if test and ISWorldObjectContextMenu.Test then return true end

    local playerObj = getSpecificPlayer(player)
    if not playerObj or playerObj:getVehicle() then return end

    local trashCan = findTrashCan(worldobjects)
    if not trashCan then return end

    local square = trashCan:getSquare()
    local campfire = CJSGarbageFire.campfireOnSquare(square)

    if CJSGarbageFire.isGarbageCampfire(campfire) then
        removeVanillaCampfireOptions(context)
        if campfire.isLit then
            if test then return ISWorldObjectContextMenu.setTest() end
            context:addOption("Put Out Trash Fire", playerObj, putOutTrashFire, campfire)
        end
        return
    elseif campfire then
        return
    end

    if test then return ISWorldObjectContextMenu.setTest() end

    local starter = firstStarter(playerObj)
    local tinder = firstTinder(playerObj)
    local option = context:addOption("Burn Trash", playerObj, burnTrash, trashCan, starter, tinder)

    if not starter or not tinder then
        option.notAvailable = true
        tooltip(option, "Burn Trash", "Requires a fire starter and a rag or unequipped piece of clothing.")
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
print("[cjsGarbageFire] Loaded client " .. CJSGarbageFire.version)
