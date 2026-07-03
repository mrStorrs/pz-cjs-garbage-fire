require "TimedActions/ISBaseTimedAction"
require "CJS_GarbageFire_Shared"

CJSBurnTrashAction = ISBaseTimedAction:derive("CJSBurnTrashAction")

function CJSBurnTrashAction:isValid()
    if not self.object or not self.object:getSquare() then return false end
    if not CJSGarbageFire.isTrashCanObject(self.object) then return false end
    if CJSGarbageFire.campfireOnSquare(self.object:getSquare()) then return false end

    local inventory = self.character:getInventory()
    return inventory:contains(self.starter) and inventory:contains(self.tinder) and
        CJSGarbageFire.isStarterItem(self.starter) and CJSGarbageFire.isTinderItem(self.tinder)
end

function CJSBurnTrashAction:waitToStart()
    self.character:faceThisObject(self.object)
    return self.character:shouldBeTurning()
end

function CJSBurnTrashAction:update()
    self.tinder:setJobDelta(self:getJobDelta())
    self.character:faceThisObject(self.object)
    self.character:setMetabolicTarget(Metabolics.HeavyDomestic)
end

function CJSBurnTrashAction:start()
    self.tinder:setJobType("Burn Trash")
    self.tinder:setJobDelta(0.0)
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Low")
    self.character:reportEvent("EventLootItem")
    self.sound = self.character:playSound("CampfireLight")
end

function CJSBurnTrashAction:stop()
    self.character:stopOrTriggerSound(self.sound)
    self.tinder:setJobDelta(0.0)
    ISBaseTimedAction.stop(self)
end

function CJSBurnTrashAction:perform()
    self.character:stopOrTriggerSound(self.sound)
    self.tinder:setJobDelta(0.0)

    self.starter:Use()
    self.character:removeFromHands(self.tinder)
    self.character:getInventory():Remove(self.tinder)

    local square = self.object:getSquare()
    local args = {
        x = square:getX(),
        y = square:getY(),
        z = square:getZ(),
        objectIndex = self.object:getObjectIndex(),
        tinderFuelMinutes = CJSGarbageFire.fuelMinutesForItem(self.tinder),
    }

    sendClientCommand(self.character, CJSGarbageFire.commandModule, "startFire", args)
    ISBaseTimedAction.perform(self)
end

function CJSBurnTrashAction:new(character, object, starter, tinder, time)
    local o = ISBaseTimedAction.new(self, character)
    o.object = object
    o.starter = starter
    o.tinder = tinder
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = time

    return o
end
