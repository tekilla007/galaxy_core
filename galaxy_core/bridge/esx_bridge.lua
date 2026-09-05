--[[
    GALAXY Core — ESX Universal Bridge (bridge/esx_bridge.lua)
    ═══════════════════════════════════════════════════════════
    Injects mock `ESX` global table and wraps every GalaxyPlayer in an xPlayer
    adapter that exposes full ESX method signatures.

    Any third-party script that calls:
        • exports['es_extended']:getSharedObject()
        • exports['es_extended']:GetPlayerFromId(src)
        • ESX.GetPlayerFromId(src)
        • xPlayer.addMoney(amount)  …etc.
    …will transparently use GALAXY Core's data.

    Load order: must run AFTER server/core.lua and bridge/qbcore_bridge.lua.
--]]

if not Galaxy.Config.Bridges.ESX then
    print('[GALAXY/ESXBridge] Disabled via config.')
    return
end

-- ─── xPlayer wrapper factory ─────────────────────────────────────────────────
-- Takes a GalaxyPlayer and returns an object with ESX method signatures.
-- Since GalaxyPlayer already exposes many ESX-compatible methods, this is
-- mostly aliasing + adding ESX-specific methods not on the base object.
local function WrapAsXPlayer(gPlayer)
    if not gPlayer then return nil end
    local pd = gPlayer.PlayerData
    local F  = gPlayer.Functions

    local xPlayer = setmetatable({}, {
        __index = function(_, key)
            -- Fall through to the raw GalaxyPlayer if key not in xPlayer
            return gPlayer[key]
        end,
    })

    -- ── Identity fields ──────────────────────────────────────────────────────
    xPlayer.source     = pd.source
    xPlayer.identifier = pd.identifier
    xPlayer.name       = pd.name
    xPlayer.group      = pd.group

    -- ── Job (ESX format) ─────────────────────────────────────────────────────
    xPlayer.job = pd.job   -- same shape thanks to BuildJobTable

    -- ── Accounts (ESX array format) ──────────────────────────────────────────
    xPlayer.accounts  = pd.accounts
    xPlayer.inventory = pd.inventory
    xPlayer.maxWeight = pd.maxWeight
    xPlayer.weight    = pd.weight
    xPlayer.loadout   = pd.loadout

    -- ── Money methods ────────────────────────────────────────────────────────
    function xPlayer.getMoney()
        return F.GetMoney('cash')
    end

    function xPlayer.addMoney(amount)
        return F.AddMoney('cash', amount, 'esx_addMoney')
    end

    function xPlayer.removeMoney(amount)
        return F.RemoveMoney('cash', amount, 'esx_removeMoney')
    end

    function xPlayer.setMoney(amount)
        return F.SetMoney('cash', amount)
    end

    -- Named account operations
    function xPlayer.getAccount(accountName)
        return F.GetAccount(accountName)
    end

    function xPlayer.addAccountMoney(accountName, amount)
        return F.AddAccountMoney(accountName, amount)
    end

    function xPlayer.removeAccountMoney(accountName, amount)
        return F.RemoveAccountMoney(accountName, amount)
    end

    function xPlayer.setAccountMoney(accountName, amount)
        return F.SetAccountMoney(accountName, amount)
    end

    -- ── Inventory methods ────────────────────────────────────────────────────
    function xPlayer.getInventoryItem(itemName)
        local item = F.GetItemByName(itemName)
        if not item then
            return { name = itemName, count = 0, weight = 0, label = itemName }
        end
        -- normalise: ox_inventory uses .count, ESX uses .count — compatible
        return item
    end

    function xPlayer.addInventoryItem(itemName, count)
        return F.AddItem(itemName, count)
    end

    function xPlayer.removeInventoryItem(itemName, count)
        return F.RemoveItem(itemName, count)
    end

    function xPlayer.setInventoryItem(itemName, count)
        -- ESX: set exact count — remove all then add desired amount
        F.RemoveItem(itemName, 99999)
        if count > 0 then
            F.AddItem(itemName, count)
        end
    end

    function xPlayer.canCarryItem(itemName, count)
        -- Delegate to ox_inventory weight check if available
        if GetResourceState('ox_inventory') == 'started' then
            return exports.ox_inventory:CanCarryItem(pd.source, itemName, count)
        end
        return true   -- permissive fallback
    end

    -- ── Job methods ──────────────────────────────────────────────────────────
    function xPlayer.getJob()
        return pd.job
    end

    function xPlayer.setJob(jobName, grade)
        return F.SetJob(jobName, grade)
    end

    -- ── Loadout ──────────────────────────────────────────────────────────────
    function xPlayer.getLoadout()
        return pd.loadout or {}
    end

    -- ── Misc ─────────────────────────────────────────────────────────────────
    function xPlayer.getName()
        return pd.name
    end

    function xPlayer.setName(name)
        pd.name = tostring(name)
    end

    function xPlayer.getGroup()
        return pd.group or 'user'
    end

    function xPlayer.setGroup(group)
        pd.group = group
        -- Persist group to DB
        Galaxy.DB.Execute(
            'UPDATE `galaxy_players` SET `group` = ? WHERE `license` = ?',
            { group, pd.license }
        )
    end

    function xPlayer.kick(reason)
        DropPlayer(tostring(pd.source), reason or 'Kicked')
    end

    function xPlayer.triggerEvent(eventName, ...)
        TriggerClientEvent(eventName, pd.source, ...)
    end

    function xPlayer.showNotification(msg)
        lib.notify(pd.source, { description = msg, type = 'inform', duration = 5000 })
    end

    function xPlayer.showHelpNotification(msg)
        TriggerClientEvent('esx:showHelpNotification', pd.source, msg)
    end

    function xPlayer.getCoords()
        local ped = GetPlayerPed(tostring(pd.source))
        if ped and ped ~= 0 then
            return GetEntityCoords(ped)
        end
        return vector3(pd.position.x, pd.position.y, pd.position.z)
    end

    return xPlayer
end

-- ─── ESX Shared Object ────────────────────────────────────────────────────────
local ESX = {
    -- Metadata
    version = '1.10.2-galaxy',
    ServerVersion = '1.10.2-galaxy',

    -- Config / shared data (ESX reads these off the shared object)
    Jobs  = Galaxy.Config.Jobs,
    Items = Galaxy.Config.Items,

    -- OneSync flag
    OneSync = {
        enable  = Galaxy.Config.OneSync,
        backup  = Galaxy.Config.OneSync,
    },

    -- ── Player retrieval ─────────────────────────────────────────────────────
    GetPlayerFromId = function(source)
        local gPlayer = Galaxy.Functions.GetPlayer(tonumber(source))
        return gPlayer and WrapAsXPlayer(gPlayer) or nil
    end,

    GetPlayerFromIdentifier = function(identifier)
        local gPlayer = Galaxy.Functions.GetPlayerByIdentifier(identifier)
        return gPlayer and WrapAsXPlayer(gPlayer) or nil
    end,

    GetPlayers = function()
        return Galaxy.Functions.GetPlayers()
    end,

    GetExtendedPlayers = function(key, val)
        local result = {}
        for _, gPlayer in pairs(Galaxy.Players) do
            local pd = gPlayer.PlayerData
            local match = true
            if key and val then
                match = (pd[key] == val)
            end
            if match then
                result[#result + 1] = WrapAsXPlayer(gPlayer)
            end
        end
        return result
    end,

    -- ── Item system ──────────────────────────────────────────────────────────
    RegisterUsableItem = function(itemName, callback)
        Galaxy.Economy.RegisterUsableItem(itemName, callback)
    end,

    UseItem = function(source, item)
        local itemName = type(item) == 'table' and item.name or tostring(item)
        Galaxy.Economy.UseItem(tonumber(source), itemName, item)
    end,

    -- ── Jobs ─────────────────────────────────────────────────────────────────
    GetJobs = function()
        return Galaxy.Config.Jobs
    end,

    -- ── Notification ─────────────────────────────────────────────────────────
    ShowNotification = function(source, msg)
        lib.notify(source, { description = msg, type = 'inform', duration = 5000 })
    end,

    -- ── Utility ──────────────────────────────────────────────────────────────
    Trace = function(msg)
        if Galaxy.Config.Debug then
            print('[ESX:Trace] ' .. tostring(msg))
        end
    end,

    SetTimeout = function(msec, cb)
        SetTimeout(msec, cb)
    end,

    -- Self-reference (ESX.GetSharedObject pattern)
    GetSharedObject = function()
        return ESX
    end,
}

-- Alias getSharedObject (lowercase — used by old ESX resources)
ESX.getSharedObject = ESX.GetSharedObject

-- ─── Inject into global environment ──────────────────────────────────────────
_G.ESX = ESX

-- ─── Exports consumed by:
--     exports['es_extended']:getSharedObject()
--     exports['es_extended']:GetPlayerFromId(src)  …etc.
exports('getSharedObject',        ESX.GetSharedObject)
exports('GetSharedObject',        ESX.GetSharedObject)
exports('GetPlayerFromId',        ESX.GetPlayerFromId)
exports('GetPlayerFromIdentifier',ESX.GetPlayerFromIdentifier)
exports('GetPlayers',             ESX.GetPlayers)
exports('GetExtendedPlayers',     ESX.GetExtendedPlayers)
exports('RegisterUsableItem',     ESX.RegisterUsableItem)
exports('UseItem',                ESX.UseItem)
exports('GetJobs',                ESX.GetJobs)

-- Store reference for event_bridge and external use
Galaxy.ESX        = ESX
Galaxy.WrapAsXPlayer = WrapAsXPlayer

print('[GALAXY/ESXBridge] ESX (es_extended) compatibility layer active.')
