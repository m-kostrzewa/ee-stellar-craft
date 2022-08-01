lastCallbackId = 0
callbacks = {}

function registerAtSecondsCallback(atSeconds, func)
    lastCallbackId = lastCallbackId + 1

    local cb = {atSeconds = atSeconds, func = func}
    callbacks[lastCallbackId] = cb

    print("[Callback] Registering id=" .. lastCallbackId .. " atSeconds=" .. atSeconds)
    return lastCallbackId
end

function unregisterAtSecondsCallback(id)
    print("[Callback] Unregistering " .. id)
    callbacks[id] = nil
end

function updateCallbacks(delta)
    local currentSeconds = getScenarioTime()
    for id=1, lastCallbackId do
        if callbacks[id] ~= nil and currentSeconds >= callbacks[id].atSeconds then
            callbacks[id].func(id)
            unregisterAtSecondsCallback(id)
        end
    end
end
