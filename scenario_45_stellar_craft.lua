-- Name: Stellar Craft
-- Description: Build up your base, construct new ships and conquer!
---
-- Type: Replayable Mission
-- Author: Kosai

--- Scenario
-- @script scenario_45_stellar_craft

require("stellar_craft/main.lua")

function init()
    local status, err = pcall(myInit)
    if not status then
        print("Error in myInit: ", err)
    end
end

function update(delta)
    local status, err = pcall(myUpdate, delta)
    if not status then
        print("Error in myUpdate: ", err)
    end
end
