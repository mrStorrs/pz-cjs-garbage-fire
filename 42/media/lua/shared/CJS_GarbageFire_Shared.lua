CJSGarbageFire = CJSGarbageFire or {}

CJSGarbageFire.version = "0.1.1"
CJSGarbageFire.commandModule = "CJSGarbageFire"
CJSGarbageFire.modDataKey = "CJS_GarbageFire"
CJSGarbageFire.maxFuelMinutes = 180
CJSGarbageFire.minFuelMinutes = 5

local unpackArgs = unpack or table.unpack

local ragTypes = {
    AlcoholRippedSheets = true,
    DenimStrips = true,
    DenimStripsDirty = true,
    LeatherStrips = true,
    LeatherStripsDirty = true,
    RippedSheets = true,
    RippedSheetsDirty = true,
}

local trashNameTokens = {
    "dumpster",
    "garbage",
    "public garbage",
    "recycle bin",
    "round bin",
    "trash can",
    "wheeliebin",
    "wheelie bin",
}

function CJSGarbageFire.call(object, methodName, ...)
    if not object then return nil end

    local method = object[methodName]
    if not method then return nil end

    local args = { ... }
    local ok, result = pcall(function()
        return method(object, unpackArgs(args))
    end)

    if ok then return result end
    return nil
end

local function lower(value)
    if value == nil then return "" end
    return string.lower(tostring(value))
end

local function hasText(value)
    return value ~= nil and value ~= false and tostring(value) ~= ""
end

local function itemUsesRemaining(item)
    local uses = tonumber(CJSGarbageFire.call(item, "getCurrentUses") or 0)
    if uses and uses > 0 then return uses end

    uses = tonumber(CJSGarbageFire.call(item, "getDrainableUsesInt") or 0)
    if uses and uses > 0 then return uses end

    local floatUses = tonumber(CJSGarbageFire.call(item, "getCurrentUsesFloat") or 0)
    if floatUses and floatUses > 0 then return math.max(1, math.ceil(floatUses)) end

    return 0
end

local function spriteProperties(object)
    local sprite = CJSGarbageFire.call(object, "getSprite")
    if not sprite then return nil end
    return CJSGarbageFire.call(sprite, "getProperties")
end

function CJSGarbageFire.propertyIs(object, name)
    local props = spriteProperties(object)
    if not props then return false end

    return props:has(name) == true
end

function CJSGarbageFire.propertyValue(object, name)
    local props = spriteProperties(object)
    if not props then return nil end

    if not props:has(name) then return nil end
    return props:get(name)
end

function CJSGarbageFire.objectDisplayName(object)
    local customName = CJSGarbageFire.propertyValue(object, "CustomName")
    local groupName = CJSGarbageFire.propertyValue(object, "GroupName")

    if hasText(groupName) and hasText(customName) then
        return tostring(groupName) .. " " .. tostring(customName)
    end

    if hasText(customName) then return tostring(customName) end
    return tostring(CJSGarbageFire.call(object, "getName") or "")
end

local function containsTrashName(value)
    value = lower(value)
    if value == "" then return false end

    for _, token in ipairs(trashNameTokens) do
        if string.find(value, token, 1, true) then return true end
    end

    return false
end

function CJSGarbageFire.isTrashCanObject(object)
    if not object then return false end
    if instanceof and instanceof(object, "IsoWorldInventoryObject") then return false end

    local container = CJSGarbageFire.call(object, "getContainer")
    if not container then return false end

    if CJSGarbageFire.propertyIs(object, "IsTrashCan") then return true end

    if containsTrashName(CJSGarbageFire.objectDisplayName(object)) then return true end
    if containsTrashName(CJSGarbageFire.call(container, "getType")) then return true end

    return false
end

local function isDrainableWithUses(item)
    if CJSGarbageFire.call(item, "IsDrainable") then return itemUsesRemaining(item) > 0 end

    return true
end

function CJSGarbageFire.isStarterItem(item)
    if not item then return false end

    local itemType = CJSGarbageFire.call(item, "getType")
    local startFireTag = ItemTag and ItemTag.START_FIRE
    local tagged = startFireTag and item:hasTag(startFireTag) == true

    if tagged or itemType == "Lighter" or itemType == "Matches" then
        return isDrainableWithUses(item)
    end

    return false
end

function CJSGarbageFire.isRagItem(item)
    if not item then return false end
    if CJSGarbageFire.call(item, "isFavorite") then return false end

    return ragTypes[CJSGarbageFire.call(item, "getType")] == true
end

local function clothingCanBurnAsTinder(item)
    if not item then return false end
    if not CJSGarbageFire.call(item, "IsClothing") then return false end
    if CJSGarbageFire.call(item, "isEquipped") then return false end

    local fabricType = CJSGarbageFire.call(item, "getFabricType")
    if not hasText(fabricType) or tostring(fabricType) == "Leather" then return false end

    return tonumber(CJSGarbageFire.call(item, "getWetness") or 0) <= 0
end

local function genericItemCanBurn(item)
    if not item then return false end
    if CJSGarbageFire.call(item, "IsClothing") then return clothingCanBurnAsTinder(item) end

    local fluidContainer = CJSGarbageFire.call(item, "getFluidContainer")
    if fluidContainer and tonumber(CJSGarbageFire.call(fluidContainer, "getAmount") or 0) > 0 then
        return false
    end

    if instanceof and instanceof(item, "InventoryContainer") then
        local inventory = CJSGarbageFire.call(item, "getInventory")
        if inventory and CJSGarbageFire.call(inventory, "isEmpty") ~= true then
            return false
        end
    end

    return true
end

local function hasTinderValue(itemType, category)
    if campingLightFireType and campingLightFireType[itemType] and campingLightFireType[itemType] ~= 0 then
        return true
    end

    if campingLightFireCategory and campingLightFireCategory[category] and campingLightFireCategory[category] ~= 0 then
        return true
    end

    return false
end

function CJSGarbageFire.isTinderItem(item)
    if not item then return false end
    if CJSGarbageFire.call(item, "isFavorite") then return false end
    if CJSGarbageFire.isRagItem(item) then return true end

    local itemType = CJSGarbageFire.call(item, "getType")
    local category = CJSGarbageFire.call(item, "getCategory")

    if CJSGarbageFire.call(item, "hasTag", "NotFireTinder") then return false end
    if CJSGarbageFire.call(item, "hasTag", "IsFireTinder") then return genericItemCanBurn(item) end
    if hasTinderValue(itemType, category) then return genericItemCanBurn(item) end
    if clothingCanBurnAsTinder(item) then return true end

    return false
end

function CJSGarbageFire.isRagOrClothing(item)
    return CJSGarbageFire.isTinderItem(item)
end

function CJSGarbageFire.fuelItemUses(item)
    if not item then return 0 end
    if not CJSGarbageFire.call(item, "IsDrainable") then return 1 end

    local uses = itemUsesRemaining(item)
    if uses < 1 then return 1 end
    return uses
end

function CJSGarbageFire.fuelMinutesForItem(item)
    if not item then return 0 end

    local itemType = CJSGarbageFire.call(item, "getType")
    local category = CJSGarbageFire.call(item, "getCategory")
    local fuelHours = nil

    if campingFuelType and campingFuelType[itemType] then
        fuelHours = campingFuelType[itemType]
    elseif campingLightFireType and campingLightFireType[itemType] then
        fuelHours = campingLightFireType[itemType]
    elseif campingFuelCategory and campingFuelCategory[category] then
        fuelHours = campingFuelCategory[category]
    elseif campingLightFireCategory and campingLightFireCategory[category] then
        fuelHours = campingLightFireCategory[category]
    elseif ragTypes[itemType] then
        fuelHours = 5 / 60
    elseif CJSGarbageFire.call(item, "IsClothing") and hasText(CJSGarbageFire.call(item, "getFabricType")) then
        fuelHours = 15 / 60
    end

    if not fuelHours or fuelHours <= 0 then return 0 end
    return fuelHours * 60 * CJSGarbageFire.fuelItemUses(item)
end

function CJSGarbageFire.campfireOnSquare(square)
    if not square then return nil end

    local system = nil
    if CCampfireSystem and CCampfireSystem.instance then
        system = CCampfireSystem.instance
    elseif SCampfireSystem and SCampfireSystem.instance then
        system = SCampfireSystem.instance
    end

    if not system then return nil end
    return CJSGarbageFire.call(system, "getLuaObjectOnSquare", square)
end

function CJSGarbageFire.isGarbageCampfire(campfire)
    if not campfire then return false end

    local isoObject = CJSGarbageFire.call(campfire, "getIsoObject") or CJSGarbageFire.call(campfire, "getObject")
    local modData = isoObject and CJSGarbageFire.call(isoObject, "getModData")

    return modData and modData[CJSGarbageFire.modDataKey] == true
end

function CJSGarbageFire.garbageCampfireOnSquare(square)
    local campfire = CJSGarbageFire.campfireOnSquare(square)
    if CJSGarbageFire.isGarbageCampfire(campfire) then return campfire end
    return nil
end
