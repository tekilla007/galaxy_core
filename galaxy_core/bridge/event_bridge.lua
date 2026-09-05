--[[
    GALAXY Core — Universal Event Bridge (bridge/event_bridge.lua)
    ══════════════════════════════════════════════════════════════
    Maps Galaxy's internal lifecycle events to every legacy event name that
    third-party scripts expect, in all three ecosystems.

    Internal events → Legacy events fired:
    ───────────────────────────────────────────────────────────────────────────
    galaxy:server:characterLoaded   →  QBCore:Server:OnPlayerLoaded   (server)
                                    →  esx:playerLoaded               (server)
                                    →  Qbx:Player:Loaded              (server)
                                    →  QBCore:Client:OnPlayerLoaded   (client)
                                    →  esx:onPlayerSpawn              (client)

    galaxy:server:playerDropped     →  QBCore:Server:OnPlayerUnload   (server)
                                    →  esx:playerDropped              (server)

    galaxy:server:setJob            →  QBCore:Server:SetJob           (server)
                                    →  esx:setJob                     (server)
                                    →  QBCore:Client:OnJobUpdate      (client)
                                    →  esx:setJob                     (client)

    galaxy:server:setGang           →  QBCore:Server:SetGang          (server)

    galaxy:server:playerDied        →  QBCore:Server:OnPlayerDeath    (server)
                                    →  esx:onPlayerDeath              (server)

    galaxy:server:moneyChange       →  esx:setAccountMoney            (client)
--]]

-- ─── Character Loaded ─────────────────────────────────────────────────────────
AddEventHandler('galaxy:server:characterLoaded', function(source, gPlayer)
    local pd = gPlayer.PlayerData

    -- QBCore / QBX server events
    TriggerEvent('QBCore:Server:OnPlayerLoaded', source)
    TriggerEvent('Qbx:Player:Loaded', source)

    -- ESX server event
    -- isNew: check if character was just created (slot = most recently created)
    local isNew = false
    TriggerEvent('esx:playerLoaded', source, gPlayer, isNew)   -- gPlayer also acts as xPlayer

    -- Client-side events
    -- QBCore: fire OnPlayerLoaded with full PlayerData
    TriggerClientEvent('QBCore:Client:OnPlayerLoaded', source)
    TriggerClientEvent('QBCore:Player:SetPlayerData',  source, pd)

    -- ESX: client playerLoaded — passes xPlayer-compatible data
    TriggerClientEvent('esx:playerLoaded', source, pd, isNew)
    TriggerClientEvent('esx:onPlayerSpawn', source)

    -- QBX
    TriggerClientEvent('Qbx:Client:OnPlayerLoaded', source)
end)

-- ─── Player Dropped ───────────────────────────────────────────────────────────
AddEventHandler('galaxy:server:playerDropped', function(source, gPlayer)
    -- QBCore server
    TriggerEvent('QBCore:Server:OnPlayerUnload', source)

    -- ESX server
    local reason = 'disconnect'
    TriggerEvent('esx:playerDropped', source, reason)
    TriggerEvent('esx:playerLogout',  source)
end)

-- ─── Job Changed ──────────────────────────────────────────────────────────────
AddEventHandler('galaxy:server:setJob', function(source, job, lastJob)
    -- QBCore server
    TriggerEvent('QBCore:Server:SetJob', source, job, lastJob)

    -- ESX server
    TriggerEvent('esx:setJob', source, job, lastJob)

    -- QBCore client — sends updated PlayerData
    local gPlayer = Galaxy.Functions.GetPlayer(source)
    if gPlayer then
        TriggerClientEvent('QBCore:Player:SetPlayerData', source, gPlayer.PlayerData)
        TriggerClientEvent('QBCore:Client:OnJobUpdate',   source, job, lastJob)
    end

    -- ESX client
    TriggerClientEvent('esx:setJob', source, job)
end)

-- ─── Gang Changed ─────────────────────────────────────────────────────────────
AddEventHandler('galaxy:server:setGang', function(source, gang, lastGang)
    TriggerEvent('QBCore:Server:SetGang', source, gang, lastGang)

    local gPlayer = Galaxy.Functions.GetPlayer(source)
    if gPlayer then
        TriggerClientEvent('QBCore:Player:SetPlayerData', source, gPlayer.PlayerData)
    end
end)

-- ─── Money Changed ────────────────────────────────────────────────────────────
AddEventHandler('galaxy:server:moneyChange', function(source, moneyType, action, amount, reason)
    -- ESX client: notify of account money change
    local gPlayer = Galaxy.Functions.GetPlayer(source)
    if not gPlayer then return end

    -- ESX fires esx:setAccountMoney on the client with the new balance
    local newBalance = gPlayer.Functions.GetMoney(moneyType)
    TriggerClientEvent('esx:setAccountMoney', source, moneyType, newBalance)
end)

-- ─── Player Death ─────────────────────────────────────────────────────────────
AddEventHandler('galaxy:server:playerDied', function(source, isDead, killerData)
    TriggerEvent('QBCore:Server:OnPlayerDeath', source, isDead, killerData or {})
    TriggerEvent('esx:onPlayerDeath', source, isDead, killerData or {})
end)

-- ─── Reverse bridge: translate QBCore/ESX → Galaxy ───────────────────────────
-- Some resources TriggerEvent() a legacy event on the server rather than
-- using exports. We catch those here and re-fire them as Galaxy events.

-- QBCore: player manually calls setJob via a server event (some old scripts)
RegisterNetEvent('QBCore:Server:SetJob')
AddEventHandler('QBCore:Server:SetJob', function(jobName, grade)
    local source  = source
    local gPlayer = Galaxy.Functions.GetPlayer(source)
    if gPlayer then
        gPlayer.Functions.SetJob(jobName, grade)
    end
end)

-- ESX: old resources fire esx:addInventoryItem on server
RegisterNetEvent('esx:addInventoryItem')
AddEventHandler('esx:addInventoryItem', function(source, itemName, count)
    -- Note: source here is the net ID passed as arg (some scripts do this)
    local target  = type(source) == 'number' and source or (source --[[ fallback ]])
    local gPlayer = Galaxy.Functions.GetPlayer(target)
    if gPlayer then
        gPlayer.Functions.AddItem(itemName, count)
    end
end)

-- ESX: removeInventoryItem
RegisterNetEvent('esx:removeInventoryItem')
AddEventHandler('esx:removeInventoryItem', function(source, itemName, count)
    local target  = type(source) == 'number' and source or source
    local gPlayer = Galaxy.Functions.GetPlayer(target)
    if gPlayer then
        gPlayer.Functions.RemoveItem(itemName, count)
    end
end)

-- ─── Client-side legacy event relay ───────────────────────────────────────────
-- Some ESX resources fire esx:useItem from the client
RegisterNetEvent('esx:useItem')
AddEventHandler('esx:useItem', function(itemName)
    local source = source
    Galaxy.Economy.UseItem(source, itemName)
end)

-- QBCore: legacy client → server callback trigger (compatibility)
RegisterNetEvent('QBCore:Server:TriggerCallback')
AddEventHandler('QBCore:Server:TriggerCallback', function(name, requestId, ...)
    local source = source
    local cb = function(...)
        TriggerClientEvent('QBCore:Client:TriggerCallback', source, requestId, ...)
    end
    local handler = Galaxy.Callbacks.Registered and Galaxy.Callbacks.Registered[name]
    -- Fallback: route through galaxy callback system
    TriggerEvent('galaxy:server:triggerCallback', name, requestId, ...)
end)

print('[GALAXY/EventBridge] Legacy event mapping active (QBCore + QBX + ESX).')
