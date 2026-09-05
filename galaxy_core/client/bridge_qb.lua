--[[
    GALAXY Core — Client QBCore/QBX Bridge (client/bridge_qb.lua)
    ═════════════════════════════════════════════════════════════
    Injects the `QBCore` global on the CLIENT so third-party scripts that call:
        local QBCore = exports['qb-core']:GetCoreObject()
        QBCore.Functions.GetPlayerData()
        QBCore.Functions.Notify(...)
        QBCore.Functions.HasItem(...)
        QBCore.Functions.TriggerCallback(...)
    …work transparently on the GALAXY framework.
--]]

-- ─── Client QBCore mock ───────────────────────────────────────────────────────
local QBCore = {
    Config = {
        Locale = Galaxy.Config.Locale,
        Prefix = Galaxy.Config.Prefix,
    },
    Shared = {
        Jobs   = Galaxy.Config.Jobs,
        Gangs  = Galaxy.Config.Gangs,
        Items  = Galaxy.Config.Items,
    },
    Functions = {},
    PlayerData = {},   -- will be kept in sync via SetPlayerData event
}

-- ─── GetPlayerData: returns local cached PlayerData ───────────────────────────
function QBCore.Functions.GetPlayerData()
    return Galaxy.PlayerData
end

-- ─── Notifications ────────────────────────────────────────────────────────────
function QBCore.Functions.Notify(text, notifyType, duration)
    lib.notify({
        description = tostring(text),
        type        = notifyType or 'inform',
        duration    = duration or 5000,
    })
end

-- ─── DrawText / HideText (many scripts use these) ─────────────────────────────
function QBCore.Functions.DrawText(text, alignment)
    -- Route through ox_lib's TextUI if available
    lib.showTextUI(tostring(text), { position = alignment or 'left-center' })
end

function QBCore.Functions.HideText()
    lib.hideTextUI()
end

-- ─── HasItem (client-side check on local inventory cache) ─────────────────────
function QBCore.Functions.HasItem(itemName)
    local pd = Galaxy.PlayerData
    if not pd then return false end
    -- With ox_inventory, check via export
    if GetResourceState('ox_inventory') == 'started' then
        local item = exports.ox_inventory:GetSlotWithItem(itemName)
        return item ~= nil and item.count > 0
    end
    -- Fallback: search items array
    if pd.items then
        for _, item in ipairs(pd.items) do
            if item.name == itemName and (item.count or item.amount or 0) > 0 then
                return true
            end
        end
    end
    return false
end

-- ─── Callback system (client-side trigger) ────────────────────────────────────
function QBCore.Functions.TriggerCallback(name, cb, ...)
    Galaxy.TriggerCallback(name, cb, ...)
end

-- ─── Callback response relay ─────────────────────────────────────────────────
-- QBCore resources also listen for 'QBCore:Client:TriggerCallback'
RegisterNetEvent('QBCore:Client:TriggerCallback', function(requestId, ...)
    -- re-route through Galaxy's callback pool
    TriggerEvent('galaxy:client:callbackResponse', requestId, ...)
end)

-- ─── PlayerData sync ─────────────────────────────────────────────────────────
RegisterNetEvent('QBCore:Player:SetPlayerData', function(data)
    QBCore.PlayerData = data
    Galaxy.PlayerData = data
    TriggerEvent('QBCore:Player:SetPlayerData', data)
end)

-- ─── Player lifecycle events ──────────────────────────────────────────────────
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    QBCore.PlayerData = Galaxy.PlayerData
    TriggerEvent('QBCore:Client:OnPlayerLoaded')
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    QBCore.PlayerData = {}
    TriggerEvent('QBCore:Client:OnPlayerUnload')
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job, lastJob)
    if Galaxy.PlayerData then
        Galaxy.PlayerData.job = job
        QBCore.PlayerData.job = job
    end
    TriggerEvent('QBCore:Client:OnJobUpdate', job, lastJob)
end)

-- ─── Inject into global environment ──────────────────────────────────────────
_G.QBCore = QBCore

-- ─── Exports: allow scripts to call exports['qb-core']:GetCoreObject() ────────
-- (The export name 'GetCoreObject' is already registered in fxmanifest.lua)
-- We simply expose the object here.

print('[GALAXY/Client/QBBridge] QBCore client bridge active.')
