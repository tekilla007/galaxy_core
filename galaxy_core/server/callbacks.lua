--[[
    GALAXY Core — Server-Side Callback System (server/callbacks.lua)
    Provides a lightweight callback mechanism compatible with both:
      - QBCore native callbacks  (QBCore.Functions.CreateCallback / TriggerCallback)
      - ox_lib callbacks         (lib.callback.register)
    Both systems co-exist; resources can use either.
--]]

Galaxy.Callbacks = {}
local Callbacks = Galaxy.Callbacks

local Registered = {}    -- { [name] = function(source, cb, ...) }
local Pending    = {}    -- { [callbackId] = { source, resolve } }

--- Register a server-side callback that clients can trigger.
---@param name string
---@param callback function  receives (source, cb, ...) where cb(result) sends the response
function Callbacks.Register(name, callback)
    if Registered[name] then
        print(('[GALAXY/Callbacks] Warning: overwriting existing callback "%s"'):format(name))
    end
    Registered[name] = callback
    if Galaxy.Config.Debug then
        print(('[GALAXY/Callbacks] Registered: %s'):format(name))
    end
end

-- Alias used by QBCore resources
Callbacks.CreateCallback = Callbacks.Register

-- ─── Network handler: client requests a callback ───────────────────────────────
RegisterNetEvent('galaxy:server:triggerCallback', function(name, requestId, ...)
    local source = source
    local cb = Registered[name]
    if not cb then
        print(('[GALAXY/Callbacks] Unknown callback requested: "%s" from %d'):format(name, source))
        TriggerClientEvent('galaxy:client:callbackResponse', source, requestId, nil)
        return
    end

    -- Resolver: called by the registered handler with the result
    local function resolve(...)
        TriggerClientEvent('galaxy:client:callbackResponse', source, requestId, ...)
    end

    local ok, err = pcall(cb, source, resolve, ...)
    if not ok then
        print(('[GALAXY/Callbacks] Error in callback "%s": %s'):format(name, tostring(err)))
        TriggerClientEvent('galaxy:client:callbackResponse', source, requestId, nil)
    end
end)

-- ─── Pre-registered core callbacks ────────────────────────────────────────────

-- Get player data
Callbacks.Register('galaxy:getPlayerData', function(source, cb)
    local player = Galaxy.Functions.GetPlayer(source)
    cb(player and player.PlayerData or nil)
end)

-- Get all characters for a license
Callbacks.Register('galaxy:getCharacters', function(source, cb)
    local license = GetPlayerIdentifierByType(source, 'license')
    if not license then cb({}) return end
    cb(Galaxy.DB.GetCharacters(license))
end)

-- Check if player has item
Callbacks.Register('galaxy:hasItem', function(source, cb, itemName, amount)
    local player = Galaxy.Functions.GetPlayer(source)
    if not player then cb(false) return end
    cb(player.Functions.HasItem(itemName, amount))
end)

-- Get money
Callbacks.Register('galaxy:getMoney', function(source, cb, moneyType)
    local player = Galaxy.Functions.GetPlayer(source)
    if not player then cb(0) return end
    cb(player.Functions.GetMoney(moneyType))
end)

print('[GALAXY] Callback system loaded.')
