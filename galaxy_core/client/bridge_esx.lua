--[[
    GALAXY Core — Client ESX Bridge (client/bridge_esx.lua)
    ════════════════════════════════════════════════════════
    Injects the `ESX` global on the CLIENT so third-party ESX scripts that call:
        ESX = exports['es_extended']:getSharedObject()
        ESX.GetPlayerData()
        ESX.ShowNotification(msg)
        xPlayer methods on the client
    …work transparently on GALAXY.
--]]

-- ─── Client ESX mock ──────────────────────────────────────────────────────────
local ESX = {}

-- ── Player data access ────────────────────────────────────────────────────────
function ESX.GetPlayerData()
    return Galaxy.PlayerData
end

-- ── Notifications ─────────────────────────────────────────────────────────────
function ESX.ShowNotification(msg, notifyType, duration)
    lib.notify({
        description = tostring(msg),
        type        = notifyType or 'inform',
        duration    = duration or 5000,
    })
end

function ESX.ShowHelpNotification(msg, beep, duration)
    lib.notify({
        description = tostring(msg),
        type        = 'inform',
        duration    = duration or 5000,
    })
end

-- ── Money/accounts (client-side read from cached PlayerData) ──────────────────
function ESX.GetAccount(accountName)
    local pd = Galaxy.PlayerData
    if not pd or not pd.accounts then
        return { name = accountName, label = accountName, money = 0 }
    end
    for _, acc in ipairs(pd.accounts) do
        if acc.name == accountName then
            return acc
        end
    end
    return { name = accountName, label = accountName, money = 0 }
end

-- ── Job (client-side read) ────────────────────────────────────────────────────
function ESX.GetPlayerJob()
    local pd = Galaxy.PlayerData
    return pd and pd.job or { name = 'unemployed', label = 'Unemployed', grade = 0, grade_name = 'Civilian' }
end

-- ── Utility ───────────────────────────────────────────────────────────────────
function ESX.SetTimeout(msec, cb)
    SetTimeout(msec, cb)
end

function ESX.Trace(msg)
    if Galaxy.Config.Debug then
        print('[ESX:Trace] ' .. tostring(msg))
    end
end

-- ── Self-reference ────────────────────────────────────────────────────────────
function ESX.GetSharedObject()
    return ESX
end
ESX.getSharedObject = ESX.GetSharedObject

-- ─── Sync PlayerData from server ──────────────────────────────────────────────
RegisterNetEvent('esx:playerLoaded', function(playerData, isNew)
    if type(playerData) == 'table' then
        Galaxy.PlayerData = playerData
    end
    TriggerEvent('esx:playerLoaded', playerData, isNew)
end)

RegisterNetEvent('esx:onPlayerSpawn', function()
    TriggerEvent('esx:onPlayerSpawn')
end)

-- ─── Job sync ─────────────────────────────────────────────────────────────────
RegisterNetEvent('esx:setJob', function(job)
    if Galaxy.PlayerData then
        Galaxy.PlayerData.job = job
        ESX.GetPlayerJob = function() return job end
    end
    TriggerEvent('esx:setJob', job)
end)

-- ─── Account money sync ───────────────────────────────────────────────────────
RegisterNetEvent('esx:setAccountMoney', function(accountName, balance)
    -- Handled in client/core.lua — just re-fire local event for scripts listening
    TriggerEvent('esx:setAccountMoney', accountName, balance)
end)

-- ─── Help notification ────────────────────────────────────────────────────────
RegisterNetEvent('esx:showHelpNotification', function(msg)
    ESX.ShowHelpNotification(msg)
end)

-- ─── Inject into global environment ──────────────────────────────────────────
_G.ESX = ESX

print('[GALAXY/Client/ESXBridge] ESX client bridge active.')
