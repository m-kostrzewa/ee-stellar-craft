require("./utils.lua")
require("./stellar_craft/callbacks.lua")
require("./stellar_craft/customAi.lua")



dataSheet = {}
dataSheet["Command Center"] = {
    buildCost = -1,
    buildTime = -1,
    canBuild = {"SCV"},
    lastIndex = 1,
    isUnit = false,
    template = "Medium Station",
}
dataSheet["SCV"] = {
    buildCost = 50,
    buildTime = 5,
    canBuild = {"Fighter Bay"},
    lastIndex = 1,
    isUnit = true,
    template = "Goods Freighter 1",
    customComms = scvCustomComms,
}
dataSheet["Fighter Bay"] = {
    buildCost = 100,
    buildTime = 7,
    canBuild = {"Adder MK3"},
    squadronSize = 3,
    lastIndex = 1,
    isUnit = false,
    template = "Small Station",
}
dataSheet["Adder MK3"] = {
    buildCost = 100,
    buildTime = 7,
    canBuild = {},
    lastIndex = 1,
    isUnit = true,
    template = "Adder MK3",
}



--- Comms helpers


local function withAskForWaypoint(func)
    numWaypoints = comms_source:getWaypointCount()
    if numWaypoints < 1 then
        setCommsMessage(_("Please place a waypoint first."))
    else
        setCommsMessage(_("Specify waypoint:"))
        for i=1, numWaypoints do
            addCommsReply(_("Waypoint " .. i), function()
                dummyVar = 1
                func(comms_source:getWaypoint(i))
            end)
        end
    end
end

local function commsStandardOrders()
    addCommsReply(_("Move..."), function()
        dummyVar = 1
        withAskForWaypoint(function(wpX, wpY)
            setCommsMessage(_("Order received"))
            if comms_target.squadronLeader ~= nil then
                comms_target.squadronLeader:orderDefendLocation(wpX, wpY)
            else
                comms_target:orderDefendLocation(wpX, wpY)
            end
        end)
    end)
    addCommsReply(_("Assist me"), function()
        setCommsMessage(_("Order received"))
        if comms_target.squadronLeader ~= nil then
            comms_target.squadronLeader:orderDefendTarget(comms_source)
        else
            comms_target:orderDefendTarget(comms_source)
        end
    end)
    addCommsReply(_("Defend nearby..."), function()
        setCommsMessage(_("Which object to defend?"))
        inRange = comms_target:getObjectsInRange(5000)
        for i=1, #inRange do
            if comms_target:isFriendly(inRange[i]) then
                addCommsReply(_(inRange[i]:getCallSign()), function()
                    setCommsMessage(_("Order received"))
                    if comms_target.squadronLeader ~= nil then
                        comms_target.squadronLeader:orderDefendTarget(inRange[i])
                    else
                        comms_target:orderDefendTarget(inRange[i])
                    end
                end)
            end
        end
    end)
    --- TODO: form fleet
end

local function costToString(what)
    return dataSheet[what].buildCost .. " rep, " .. 
        dataSheet[what].buildTime .. " sec"
end


local function orderConstructFunc(what, parent)
    if not dataSheet[what].isUnit and #(parent:getObjectsInRange(4000)) > 1 then
        setCommsMessage(_("Construction site is blocked, need at least 4000 units of free space"))
        return
    end

    if comms_target:takeReputationPoints(dataSheet[what].buildCost) then
        comms_target.currentConstruction = what
        if comms_target.typeName == "CpuShip" then
            comms_target:orderIdle()
        end

        registerAtSecondsCallback(getScenarioTime() + dataSheet[what].buildTime, function()
            parent.currentConstruction = nil
            if parent:isValid() then

                constructedThing = thingFactory(parent, what)
                if parent.typeName == "CpuShip" then
                    parent:orderDefendTarget(constructedThing)
                end

                if dataSheet[parent.type].squadronSize ~= nil and dataSheet[parent.type].squadronSize > 1 then
                    squadronMembers = {constructedThing}
                    for i=1, dataSheet[parent.type].squadronSize-1 do
                        constructedEscort = thingFactory(parent, what)
                        table.insert(squadronMembers, constructedEscort)
                    end
                    intoSquadron(squadronMembers)
                end
            end
        end)
        setCommsMessage(_("Starting construction of " .. what))
    else
        setCommsMessage(_("Insufficient funds"))
    end
end

local function commsStandardBuild()
    dsEntry = dataSheet[comms_target.type]
    addCommsReply(_("Construct..."), function()
        setCommsMessage(_("What to construct?"))

        for i=1, #dsEntry.canBuild do
            thingToBuild = dsEntry.canBuild[i]
            addCommsReply(_(thingToBuild .. " (" .. costToString(thingToBuild) .. ")."), function()
                dummyVar = 1
                orderConstructFunc(thingToBuild, comms_target)
            end)
        end
    end)
end

function commsAllInOne()
    dsEntry = dataSheet[comms_target.type]
    if #dsEntry.canBuild > 0 then
        if comms_target.currentConstruction == nil then
            if dsEntry.customComms and dsEntry.customComms(comms_source, comms_target) ~= 0 then
                return
            else
                setCommsMessage(_("What should we do?"))
                if dsEntry.isUnit then
                    commsStandardOrders()
                end
                commsStandardBuild()
            end
        else
            setCommsMessage(_("We are currently constructing " .. comms_target.currentConstruction))
        end
    else
        setCommsMessage(_("What should we do?"))
        if dsEntry.isUnit then
            if dsEntry.customComms ~= nil then
                ret = dsEntry.customComms(comms_source, comms_target)
                if ret ~= 0 then
                    return
                end
            end
            commsStandardOrders()
        end
    end
end


-- Squadrons

function intoSquadron(members)
    leader = nil
    local angleSeparation = 300.0 / (#members)

    escortIdx = 0
    for i=1, #members do
        if members[i]:isValid() then
            members[i].squadronMembers = members
            if leader == nil then
                leader = members[i]
                members[i].squadronLeader = leader
            else
                escortIdx = escortIdx + 1
                local dx, dy = vectorFromAngle(30.0 + escortIdx * angleSeparation, 700)
                members[i]:orderFlyFormation(leader, dx, dy)
                members[i].squadronLeader = leader
            end
        end
    end

    leader:onDestruction(function(obj, instigator)
        dummyVar = 1
        intoSquadron(obj.squadronMembers)
    end)
end


--- Factories

function thingFactory(parent, dsName)
    dsEntry = dataSheet[dsName]

    thing = nil

    if dsEntry.isUnit then
        thing = CpuShip()
            :orderDefendTarget(parent)
    else
        thing = SpaceStation()
    end

    thing.type = dsName

    thing:setFaction(parent:getFaction())
        :setTemplate(dsEntry.template)
        :setPosition(parent:getPosition())
        :setCallSign(dsName .. " " .. dataSheet[dsName].lastIndex)
        :setScanned(true)
        :setCommsFunction(commsAllInOne)

    dataSheet[dsName].lastIndex = dataSheet[dsName].lastIndex + 1

    if #dsEntry.canBuild > 0 then
        thing.currentConstruction = nil
    end

    thing.aiState = 0

    -- scv specific, TODO refactor this
    if thing.type == "SCV" then
        thing.aiState = scvAiAsteroidMiner
        thing.currentAsteroid = nil
        thing.dropOffSite = nil
        thing.currentOre = 0
        scvOrderMineAsteroids(thing)
    end

    return thing
end
