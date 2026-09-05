--[[
    GALAXY Core — QBCore / QBX Universal Bridge (bridge/qbcore_bridge.lua)
    ═══════════════════════════════════════════════════════════════════════
    Injects mock `QBCore` global table into the server's Lua environment.
    Any third-party script that calls:
        • exports['qb-core']:GetCoreObject()
        • exports['qbx_core']:GetCoreObject()
        • exports['qbx_core']:GetPlayer(source)
        • _G.QBCore.*
    …will be transparently redirected to GALAXY Core's live data.

    This file must load AFTER server/core.lua.
--]]

if not Galaxy.Config.Bridges.QBCore then
    print('[GALAXY/QBBridge] Disabled via config.')
    return
end

-- ─── Build the QBCore Shared data tables ─────────────────────────────────────
-- Third-party scripts read QBCore.Shared.Jobs, .Items, .Gangs, etc.
local QBShared = {
    Jobs     = Galaxy.Config.Jobs,
    Gangs    = Galaxy.Config.Gangs,
    Items    = Galaxy.Config.Items,
    Vehicles = {},   -- populated externally if a vehicle config resource is used
}

-- ─── Callback wrappers ────────────────────────────────────────────────────────
local function CreateCallback(name, cb)
    Galaxy.Callbacks.Register(name, cb)
end

-- ─── Notification wrapper ─────────────────────────────────────────────────────
local function Notify(source, text, notifyType, duration)
    lib.notify(source, {
        description = tostring(text),
        type        = notifyType or 'inform',
        duration    = duration or 5000,
    })
end

-- ─── The QBCore mock table ────────────────────────────────────────────────────
local QBCore = {
    -- Shared / config data
    Config = {
        StartingMoney = {
            cash        = Galaxy.Config.StartingCash,
            bank        = Galaxy.Config.StartingBank,
            black_money = Galaxy.Config.StartingBlackMoney,
        },
        Money = {
            MoneyTypes = Galaxy.Config.MoneyTypes,
        },
        Server = {
            PVPMode        = false,
            MaxPlayers     = GetConvarInt('sv_maxclients', 48),
            Whitelist      = false,
            WhitelistMode  = 'ace_permission',
        },
        Prefix   = Galaxy.Config.Prefix,
        Locale   = Galaxy.Config.Locale,
    },

    Shared = QBShared,

    -- Live player table (reference to Galaxy.Players; keeps in sync automatically)
    Players = Galaxy.Players,

    -- Commands table (so scripts can iterate registered commands)
    Commands = {},

    -- ── Functions table ───────────────────────────────────────────────────────
    Functions = {
        -- ── Player retrieval ─────────────────────────────────────────────────
        GetPlayer = function(source)
            return Galaxy.Functions.GetPlayer(tonumber(source))
        end,

        GetPlayerByCitizenId = function(citizenid)
            return Galaxy.Functions.GetPlayerByCitizenId(citizenid)
        end,

        GetPlayerByPhone = function(phone)
            return Galaxy.Functions.GetPlayerByPhone(phone)
        end,

        GetPlayers = function()
            return Galaxy.Functions.GetPlayers()
        end,

        GetQBPlayers = function()
            return Galaxy.Functions.GetQBPlayers()
        end,

        -- ── Offline data ─────────────────────────────────────────────────────
        GetOfflinePlayer = function(citizenid)
            local data = Galaxy.Functions.GetOfflinePlayer(citizenid)
            if not data then return nil end
            -- Wrap in a minimal player-like object so scripts can call
            -- .PlayerData without errors
            return { PlayerData = data, Functions = {} }
        end,

        -- ── Usable items ─────────────────────────────────────────────────────
        CreateUseableItem = function(itemName, callback)
            Galaxy.Economy.RegisterUsableItem(itemName, callback)
        end,

        -- QBX spelling variant
        CreateUsableItem = function(itemName, callback)
            Galaxy.Economy.RegisterUsableItem(itemName, callback)
        end,

        CanUseItem = function(itemName)
            return Galaxy.Economy.CanUseItem(itemName)
        end,

        -- ── Notifications ────────────────────────────────────────────────────
        Notify = Notify,

        -- ── Callbacks ────────────────────────────────────────────────────────
        CreateCallback = CreateCallback,

        -- ── Admin helpers ────────────────────────────────────────────────────
        AddPermission = function(source, perm)
            ExecuteCommand(('add_principal identifier.%s %s'):format(
                GetPlayerIdentifierByType(tostring(source), 'license') or '',
                perm
            ))
        end,

        RemovePermission = function(source, perm)
            ExecuteCommand(('remove_principal identifier.%s %s'):format(
                GetPlayerIdentifierByType(tostring(source), 'license') or '',
                perm
            ))
        end,

        HasPermission = function(source, perm)
            return IsPlayerAceAllowed(tostring(source), perm)
        end,

        -- ── Kick / Ban ───────────────────────────────────────────────────────
        Kick = function(source, reason)
            DropPlayer(tostring(source), reason or 'Kicked')
        end,

        -- ── Job helpers ──────────────────────────────────────────────────────
        GetJobs = function()
            return Galaxy.Config.Jobs
        end,

        GetGangs = function()
            return Galaxy.Config.Gangs
        end,

        DoesJobExist = function(jobName)
            return Galaxy.Config.Jobs[jobName] ~= nil
        end,

        DoesGangExist = function(gangName)
            return Galaxy.Config.Gangs[gangName] ~= nil
        end,

        -- ── Item helpers ─────────────────────────────────────────────────────
        GetItems = function()
            return Galaxy.Config.Items
        end,

        -- ── Shared object accessor (compatibility) ───────────────────────────
        GetCoreObject = function()
            return QBCore
        end,
    },

    -- ── Utils (some scripts use QBCore.Utils.*) ───────────────────────────────
    Utils = {
        DrawText = function() end,  -- client-only stub; noop on server
        HideText = function() end,
        Notify   = Notify,
    },
}

-- Alias for QBX naming convention
QBCore.Functions.GetCoreObject = QBCore.Functions.GetCoreObject

-- ─── Inject into global environment ──────────────────────────────────────────
_G.QBCore = QBCore

-- ─── Exports consumed by:
--     exports['qb-core']:GetCoreObject()
--     exports['qbx_core']:GetCoreObject()
--     exports['qbx_core']:GetPlayer(src)
--     … etc.
-- We register exports under BOTH resource name aliases.
-- Note: The actual aliases 'qb-core' and 'qbx_core' are handled by
-- the AddResourceExportAlias block in server.cfg (see recipe.yaml).
-- Here we expose them from our own resource name as a fallback.

exports('GetCoreObject',          function() return QBCore end)
exports('GetPlayer',              QBCore.Functions.GetPlayer)
exports('GetPlayers',             QBCore.Functions.GetPlayers)
exports('GetQBPlayers',           QBCore.Functions.GetQBPlayers)
exports('GetPlayerByCitizenId',   QBCore.Functions.GetPlayerByCitizenId)
exports('GetPlayerByPhone',       QBCore.Functions.GetPlayerByPhone)
exports('GetOfflinePlayer',       QBCore.Functions.GetOfflinePlayer)
exports('CreateCallback',         CreateCallback)
exports('CreateUseableItem',      QBCore.Functions.CreateUseableItem)
exports('CreateUsableItem',       QBCore.Functions.CreateUsableItem)
exports('GetJobs',                QBCore.Functions.GetJobs)
exports('GetGangs',               QBCore.Functions.GetGangs)
exports('DoesJobExist',           QBCore.Functions.DoesJobExist)
exports('DoesGangExist',          QBCore.Functions.DoesGangExist)
exports('GetItems',               QBCore.Functions.GetItems)
exports('Notify',                 Notify)

-- ─── Store reference for ESX bridge and event bridge to use ──────────────────
Galaxy.QBCore = QBCore

print('[GALAXY/QBBridge] QBCore & QBX compatibility layer active.')
