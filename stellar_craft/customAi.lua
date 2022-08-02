
require("./utils.lua")
require("./stellar_craft/callbacks.lua")
require("./stellar_craft/utils.lua")




scvAiNotMining = 0
scvAiAsteroidMiner = 1

local function findAsteroidNearby(posX, posY)
    inRange = getObjectsInRadius(posX, posY, 10000)
    shuffled = {}
    for i, v in ipairs(inRange) do
        local pos = math.random(1, #shuffled+1)
        table.insert(shuffled, pos, v)
    end
    for i=1, #shuffled do
        if shuffled[i].typeName == "Asteroid" then
            return shuffled[i]
        end
    end
    return nil
end

local function findOreDropoffNearby(posX, posY)
    for i=1, 100 do
        inRange = getObjectsInRadius(posX, posY, i*1000)
        for i=1, #inRange do
            if inRange[i].type and inRange[i].type == "Command Center" then
                return inRange[i]
            end
        end
    end
    return nil
end


scvMaxOreCargo = 50
scvOrePerBite = 10
scvOreToRepRatio = 0.1

function scvOrderMineAsteroids(thisScv)
    scvX, scvY = thisScv:getPosition()
    asteroidToMine = findAsteroidNearby(scvX, scvY)
    if asteroidToMine == nil then
        return 1
    end

    thisScv.aiState = scvAiAsteroidMiner
    thisScv.currentAsteroid = nil
    thisScv.dropOffSite = nil

    miningAiFunc = function(scvInternal)

        if scvInternal:isValid() then

            if scvInternal.aiState == scvAiNotMining then
                return
            end

            if scvInternal.currentOre >= scvMaxOreCargo then
                if scvInternal.dropOffSite == nil then
                    scvX, scvY = scvInternal:getPosition()
                    scvInternal.dropOffSite = findOreDropoffNearby(scvX, scvY)

                    if scvInternal.dropOffSite == nil then
                        scvInternal:sendCommsMessage(getPlayerShip(-1), _(scvInternal:getCallSign() .. " here, we can't find suitable spot to drop of our ore. Requesting manual guidance."))
                        scvInternal.aiState = scvAiNotMining
                    end

                    scvInternal:orderDock(scvInternal.dropOffSite)
                else
                    scvX, scvY = scvInternal:getPosition()
                    if scvInternal:isDocked(scvInternal.dropOffSite) then
                        scvInternal:addReputationPoints(scvInternal.currentOre * scvOreToRepRatio)
                        scvInternal.currentOre = 0
                        scvInternal.dropOffSite = nil
                        scvInternal.currentAsteroid = nil
                    end
                end
            else
                if scvInternal.currentAsteroid == nil or not scvInternal.currentAsteroid:isValid() then

                    scvInternal.currentAsteroid = findAsteroidNearby(scvX, scvY)
                    
                    if scvInternal.currentAsteroid == nil then
                        scvInternal:sendCommsMessage(getPlayerShip(-1), _(scvInternal:getCallSign() .. " here, we can't any asteroids to mine in range (5k). Requesting manual guidance."))
                        scvInternal.aiState = scvAiNotMining
                    end

                    offX, offY = vectorFromAngle(random(0, 360), 500)
                    scvInternal:orderFlyFormation(scvInternal.currentAsteroid, offX, offY) 
                else
                    scvX, scvY = scvInternal:getPosition()
                    astX, astY = scvInternal.currentAsteroid:getPosition()

                    if distance(scvX, scvY, astX, astY) < 1000 then
                        scvInternal:orderIdle()
                        BeamEffect():setSource(scvInternal, 0, 0, 0):setTarget(scvInternal.currentAsteroid, 0, 0):
                            setBeamFireSoundPower(0):setRing(false):setDuration(0.8)
                        oldSize = scvInternal.currentAsteroid:getSize()
                        newSize = math.max(1, scvInternal.currentAsteroid:getSize() - scvOrePerBite)
                        scvInternal.currentAsteroid:setSize(newSize)
                        scvInternal.currentOre = scvInternal.currentOre + oldSize - newSize

                        if scvInternal.currentAsteroid:getSize() == 1 then
                            scvInternal.currentAsteroid:destroy()
                        end
                    end
                end
            end
            registerAtSecondsCallback(getScenarioTime() + 1, function() miningAiFunc(scvInternal) end)
        end
    end
    registerAtSecondsCallback(getScenarioTime() + 1, function() miningAiFunc(thisScv) end)
    return 0
end

function scvCustomComms(origCommsSource, thisScv)
    dsEntry = dataSheet[thisScv.type]

    if comms_target.aiState ~= scvAiNotMining then
        setCommsMessage(_("We're currently conducting asteroid mining operations. We have " .. comms_target.currentOre .. " ore in our cargo bay. What should we do?"))
        addCommsReply(_("Abort mining."), function()
            setCommsMessage(_("Aborting mining operations."))
            comms_target.aiState = scvAiNotMining
            comms_target.currentAsteroid = nil
            comms_target.dropOffSite = nil
            scvX, scvY = comms_target:getPosition()
            comms_target:orderDefendLocation(scvX, scvY)
        end)
        return 1 -- quick return.
    else
        addCommsReply(_("Mine asteroids"), function()
            local ret = scvOrderMineAsteroids(comms_target)
            if ret ~= 0 then
                setCommsMessage(_("No asteroid detected within range (5k)."))
            else
                setCommsMessage(_("Order received."))
            end
        end)
    end

    return 0
end

