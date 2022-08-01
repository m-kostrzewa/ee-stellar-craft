require("./stellar_craft/callbacks.lua")
require("./stellar_craft/construction.lua")

commandCenter = nil

function myInit()
    print([[
        ____ ___ ____ _    _    ____ ____ ____ ____ ____ ____ ___ 
        [__   |  |___ |    |    |__| |__/ |    |__/ |__| |___  |  
        ___]  |  |___ |___ |___ |  | |  \ |___ |  \ |  | |     | 0.1
                                                    by Kosai
    ]])

    player = PlayerSpaceship():setFaction("Human Navy"):setTemplate("Phobos M3P"):setCallSign("Maru"):setWarpDrive(true)
    player:setPosition(2000, 2100):setReputationPoints(2000)

    commandCenter = thingFactory(player, "Command Center")
    commandCenter:setPosition(2300, 2400)
    commandCenter:onDestruction(function(obj, instigator)
        globalMessage("We've lost the Command Center, our position is now untenable!")
        registerAtSecondsCallback(getScenarioTime() + 5, function()
                victory("Kraylor")
            end
        )
    end)

    fighterBay = thingFactory(player, "Fighter Bay")
    fighterBay:setPosition(3500, 2600)
end

function myUpdate(delta)
    updateCallbacks(delta)
end

