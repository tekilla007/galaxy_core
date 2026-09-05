--[[
    GALAXY Core — Client Core (client/core.lua)
    Manages local PlayerData cache, notification routing, and spawn logic.
    Fires both Galaxy and legacy client events so third-party scripts can hook
    into any ecosystem's client-side events.
--]]

-- ─── Local state ──────────────────────────────────────────────────────────────
local PlayerData     = {}
local IsLoggedIn     = false
local CallbackPool   = {}    -- { [requestId] = callbackFn }

-- ─── Galaxy client namespace ──────────────────────────────────────────────────
Galaxy          = Galaxy or {}
Galaxy.PlayerData = PlayerData

-- ─── Exports (client-side) ────────────────────────────────────────────────────
exports('GetCoreObject', function()
    return {
        Functions = {
            GetPlayerData = function() return PlayerData end,
            Notify        = function(text, t, d)
                lib.notify({ description = text, type = t or 'inform', duration = d or 5000 })
            end,
        },
        PlayerData = PlayerData,
    }
end)

exports('GetPlayerData', function()
    return PlayerData
end)

-- ─── Receive PlayerData from server ───────────────────────────────────────────
RegisterNetEvent('galaxy:client:syncPlayerData', function(data)
    PlayerData = data
    Galaxy.PlayerData = PlayerData
end)

-- ─── Character loaded: full spawn flow ────────────────────────────────────────
RegisterNetEvent('galaxy:client:characterLoaded', function(data)
    PlayerData  = data
    IsLoggedIn  = true
    Galaxy.PlayerData = PlayerData

    -- Spawn player at saved position
    local pos = data.position
    if pos then
        local ped = PlayerPedId()
        RequestCollisionAtCoord(pos.x, pos.y, pos.z)
        SetEntityCoords(ped, pos.x, pos.y, pos.z, false, false, false, false)
        SetEntityHeading(ped, pos.w or 0.0)
        FreezeEntityPosition(ped, false)
        SetEntityVisible(ped, true, false)
    end

    -- Notify player
    lib.notify({
        description = ('Welcome, %s!'):format(data.name),
        type        = 'success',
        duration    = 5000,
        position    = 'top',
    })

    TriggerEvent('galaxy:client:playerLoaded', PlayerData)
end)

-- ─── Connected: server says we can proceed to character select ─────────────────
RegisterNetEvent('galaxy:client:playerConnected', function(options)
    -- In a full setup you would open a character select NUI here.
    -- Without a separate char-select resource, auto-request characters:
    TriggerServerEvent('galaxy:server:requestCharacters')
end)

-- ─── Receive character list ───────────────────────────────────────────────────
RegisterNetEvent('galaxy:client:receiveCharacters', function(characters)
    -- If a char-select UI resource is running, let it handle this.
    -- Otherwise, auto-select the first character as a fallback.
    if GetResourceState('galaxy_charselect') == 'started' then
        TriggerEvent('galaxy:charselect:open', characters)
        return
    end

    if #characters > 0 then
        TriggerServerEvent('galaxy:server:selectCharacter', characters[1].citizenid)
    else
        -- No characters — send a default creation payload
        TriggerServerEvent('galaxy:server:createCharacter', {
            firstname   = 'New',
            lastname    = 'Player',
            birthdate   = '01-01-2000',
            gender      = 0,
            nationality = 'USA',
        })
    end
end)

-- ─── Character load failure ────────────────────────────────────────────────────
RegisterNetEvent('galaxy:client:characterLoadFailed', function(reason)
    lib.notify({ description = reason, type = 'error', duration = 8000 })
end)

-- ─── Notification routing ─────────────────────────────────────────────────────
RegisterNetEvent('galaxy:client:notify', function(data)
    lib.notify({
        description = data.description or data.text,
        type        = data.type or 'inform',
        duration    = data.duration or 5000,
        position    = data.position,
    })
end)

-- ─── ESX help notification compat ─────────────────────────────────────────────
RegisterNetEvent('esx:showHelpNotification', function(msg)
    lib.notify({ description = msg, type = 'inform', duration = 5000 })
end)

-- ─── Callback response handler ────────────────────────────────────────────────
RegisterNetEvent('galaxy:client:callbackResponse', function(requestId, ...)
    local cb = CallbackPool[requestId]
    if cb then
        CallbackPool[requestId] = nil
        cb(...)
    end
end)

-- Expose callback trigger so bridge layers can call it
Galaxy.TriggerCallback = function(name, cb, ...)
    local requestId = ('%s_%d_%d'):format(name, math.random(0, 999999), GetGameTimer())
    CallbackPool[requestId] = cb
    TriggerServerEvent('galaxy:server:triggerCallback', name, requestId, ...)

    -- Timeout: clean up orphaned callbacks
    SetTimeout(Galaxy.Config.CallbackTimeout, function()
        if CallbackPool[requestId] then
            CallbackPool[requestId] = nil
            if Galaxy.Config.Debug then
                print(('[GALAXY/Client] Callback timed out: %s'):format(name))
            end
        end
    end)
end

-- ─── ESX compat: esx:setAccountMoney ─────────────────────────────────────────
RegisterNetEvent('esx:setAccountMoney', function(accountName, balance)
    -- Update local PlayerData money cache
    if not PlayerData.money then return end
    local mapped = accountName == 'money' and 'cash' or accountName
    PlayerData.money[mapped] = balance
    -- Sync accounts array too
    if PlayerData.accounts then
        for _, acc in ipairs(PlayerData.accounts) do
            if acc.name == accountName then
                acc.money = balance
                break
            end
        end
    end
end)

-- ─── Death event (client-side, relay to server) ───────────────────────────────
AddEventHandler('gameEventTriggered', function(name, args)
    if name == 'CEventNetworkEntityDamage' then
        local victim, attacker, isDead = args[1], args[2], args[5]
        if isDead and victim == PlayerPedId() then
            local weapon = GetSelectedPedWeapon(attacker)
            TriggerServerEvent('galaxy:server:playerDied', {
                isDead       = true,
                killerSrc    = GetPlayerServerId(NetworkGetPlayerIndexFromPed(attacker)),
                weaponHash   = weapon,
                deathCoords  = GetEntityCoords(PlayerPedId()),
            })
        end
    end
end)

print('[GALAXY/Client] Core client loaded.')
