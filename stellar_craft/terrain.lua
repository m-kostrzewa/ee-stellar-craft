local function createInRing(objectType, amount, distMin, distMax, angleMinDeg, angleMaxDeg, centerX, centerY)
    for n = 1, amount do
        local r = random(angleMinDeg, angleMaxDeg)
        local distance = random(distMin, distMax)
        x = centerX + math.cos((r / 180) * math.pi) * distance
        y = centerY + math.sin((r / 180) * math.pi) * distance
        objectType():setPosition(x, y)
    end
end


local function combNebulas()
    local allObjs = getAllObjects()
    for i=1, #allObjs do
        if allObjs[i]:isValid() and allObjs[i].typeName == "Nebula" then

            --- remove nebulas which are right on top of each other for performance
            local inRange = allObjs[i]:getObjectsInRange(4000.0)
            for j=1, #inRange do
                if inRange[j] ~= allObjs[i] and inRange[j].typeName == "Nebula" then
                    inRange[j]:destroy()
                end
            end
        end
    end
end


function generateMapTerrain(startX, startY)

    r = random(0, 360)
    createInRing(Asteroid, 50, 3000, 10000, r, r+180, startX, startY)

    r = random(0, 360)
    createInRing(Asteroid, 50, 25000, 35000, r, r+120, startX, startY)

    r = random(0, 360)
    createInRing(Nebula, 30, 20000, 50000, r, r+90, startX, startY)


    combNebulas()

end