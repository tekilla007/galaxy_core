--[[
    GALAXY Core — Central Core Engine (server/core.lua)
    ═══════════════════════════════════════════════════
    This is the heart of the framework. It:
      • Maintains the live player registry (Galaxy.Players)
      • Exposes Galaxy.Functions.* (the public API)
      • Handles the full player connect → character select → load → drop lifecycle
      • Fires internal and legacy-compat events at each lifecycle stage
      • Exposes server exports consumed by both native and bridge callers

    Load order dependency: database.lua → player.lua → money.lua → callbacks.lua → THIS FILE
--]]

-- ─── Runtime state ────────────────────────────────────────────────────────────
Galaxy.Players  = {}     -- [source] = GalaxyPlayer
Galaxy.Loaded   = false

-- ─── Galaxy.Functions — the primary public API ────────────────────────────────
Galaxy.Functions = {}
local GF = Galaxy.Functions

--- Retrieve a live player object by server source ID.
---@param source number|string
---@return table|nil GalaxyPlayer
function GF.GetPlayer(source)
    return Galaxy.Players[tonumber(source)]
end

--- Retrieve a live player by their citizenid.
---@param citizenid string
---@return table|nil GalaxyPlayer
function GF.GetPlayerByCitizenId(citizenid)
    for _, gPlayer in pairs(Galaxy.Players) do
        if gPlayer.PlayerData.citizenid == citizenid then
            return gPlayer
        end
    end
    return nil
end

--- Retrieve a live player by their primary license identifier.
---@param identifier string  "license:abc..." format
---@return table|nil GalaxyPlayer
function GF.GetPlayerByIdentifier(identifier)
    for _, gPlayer in pairs(Galaxy.Players) do
        if gPlayer.PlayerData.license == identifier then
            return gPlayer
        end
    end
    return nil
end

--- Retrieve a live player by phone number (searches charinfo.phone).
---@param phone string
---@return table|nil GalaxyPlayer
function GF.GetPlayerByPhone(phone)
    for _, gPlayer in pairs(Galaxy.Players) do
        if gPlayer.PlayerData.charinfo and gPlayer.PlayerData.charinfo.phone == phone then
            return gPlayer
        end
    end
    return nil
end

--- Get all online player source IDs.
---@return table  array of numbers
function GF.GetPlayers()
    local ids = {}
    for src in pairs(Galaxy.Players) do
        ids[#ids + 1] = src
    end
    return ids
end

--- Get all online player objects keyed by source ID.
---@return table  { [source] = GalaxyPlayer }
function GF.GetQBPlayers()
    return Galaxy.Players
end

--- Get all xPlayer-wrapped objects (ESX compat).
---@return table  array of xPlayer wrappers
function GF.GetExtendedPlayers(filterKey, filterValue)
    local result = {}
    for _, gPlayer in pairs(Galaxy.Players) do
        if filterKey == nil or gPlayer.PlayerData[filterKey] == filterValue then
            result[#result + 1] = gPlayer   -- GalaxyPlayer also acts as xPlayer wrapper
        end
    end
    return result
end

--- Fetch an offline character's data from the database (does not create a player object).
---@param citizenid string
---@return table|nil  raw PlayerData table
function GF.GetOfflinePlayer(citizenid)
    local row = Galaxy.DB.GetCharacter(citizenid)
    if not row then return nil end
    -- We need a license to parse; read from the row itself
    return Galaxy.Player.New(-1, row, row.license).PlayerData
end

--- Notify a player (thin wrapper so bridge layers have one call to make).
---@param source number
---@param text string
---@param notifyType string
---@param duration number
function GF.Notify(source, text, notifyType, duration)
    lib.notify(source, {
        description = text,
        type        = notifyType or 'inform',
        duration    = duration or 5000,
    })
end

-- ─── Exports (consumed by all third-party scripts via exports['galaxy_core']:*) ─
exports('GetCoreObject',          function() return Galaxy end)
exports('GetPlayer',              GF.GetPlayer)
exports('GetPlayers',             GF.GetPlayers)
exports('GetQBPlayers',           GF.GetQBPlayers)
exports('GetPlayerByCitizenId',   GF.GetPlayerByCitizenId)
exports('GetPlayerByIdentifier',  GF.GetPlayerByIdentifier)
exports('GetPlayerByPhone',       GF.GetPlayerByPhone)
exports('GetOfflinePlayer',       GF.GetOfflinePlayer)
exports('GetExtendedPlayers',     GF.GetExtendedPlayers)
exports('getSharedObject',        function() return Galaxy.ESX end)  -- populated by esx_bridge
exports('GetPlayerFromId',        GF.GetPlayer)
exports('GetPlayerFromIdentifier',GF.GetPlayerByIdentifier)
exports('RegisterUsableItem',     function(name, cb) Galaxy.Economy.RegisterUsableItem(name, cb) end)
exports('UseItem',                function(src, item)
    Galaxy.Economy.UseItem(src, type(item) == 'table' and item.name or item)
end)
exports('GetJobs',  function() return Galaxy.Config.Jobs  end)
exports('GetItems', function() return Galaxy.Config.Items end)
exports('AddItem',  function(src, item, count, metadata)
    local player = GF.GetPlayer(src)
    return player and player.Functions.AddItem(item, count, nil, metadata)
end)

-- ─── Player Lifecycle ─────────────────────────────────────────────────────────

local function GetLicense(source)
    return GetPlayerIdentifierByType(tostring(source), 'license')
        or GetPlayerIdentifierByType(tostring(source), 'license2')
end

local function GetAllIdentifiers(source)
    local ids = {}
    local count = GetNumPlayerIdentifiers(tostring(source))
    for i = 0, count - 1 do
        local id = GetPlayerIdentifier(tostring(source), i)
        if id then
            local t, v = id:match('^([^:]+):(.+)$')
            if t then ids[t] = id end
        end
    end
    return ids
end

--- Internal: register a player record and wait for character selection.
local function HandlePlayerConnecting(source)
    local license = GetLicense(source)
    if not license then
        DropPlayer(source, '[GALAXY] Could not read your Rockstar license. Please restart your game.')
        return
    end

    local name = GetPlayerName(source)
    -- Upsert galaxy_players row
    local playerRow = Galaxy.DB.GetOrCreatePlayer(license, name)
    local idents    = GetAllIdentifiers(source)

    -- Store identifiers in state bag for other resources
    Player(source).state:set('license',  license, false)
    Player(source).state:set('name',     name,    false)
    GlobalState:set('galaxy:playerCount', #GF.GetPlayers() + 1, true)

    -- Notify client: ready for character selection
    TriggerClientEvent('galaxy:client:playerConnected', source, {
        multiChar = Galaxy.Config.MultiCharacter,
        maxChars  = Galaxy.Config.MaxCharacters,
    })

    if Galaxy.Config.Debug then
        print(('[GALAXY] Player connecting: %s (%s) source=%d'):format(name, license, source))
    end
end

--- Internal: fully load a character into the player registry.
---@param source number
---@param citizenid string  selected character's citizenid
local function LoadCharacter(source, citizenid)
    local license = GetLicense(source)
    if not license then return end

    local row = Galaxy.DB.GetCharacter(citizenid)
    if not row or row.license ~= license then
        TriggerClientEvent('galaxy:client:characterLoadFailed', source, 'Invalid character.')
        return
    end

    local gPlayer = Galaxy.Player.New(source, row, license)

    -- Attach group from galaxy_players
    local playerRow = Galaxy.DB.Single(
        'SELECT `group` FROM `galaxy_players` WHERE `license` = ? LIMIT 1',
        { license }
    )
    if playerRow then
        gPlayer.PlayerData.group = playerRow.group or 'user'
        gPlayer.group            = gPlayer.PlayerData.group
    end

    -- Register in live table
    Galaxy.Players[source] = gPlayer

    -- Set state bags
    Player(source).state:set('citizenid',  gPlayer.PlayerData.citizenid, true)
    Player(source).state:set('isLoggedIn', true, true)
    Player(source).state:set('job',        gPlayer.PlayerData.job.name, true)

    -- Fire GALAXY internal event
    TriggerEvent('galaxy:server:characterLoaded', source, gPlayer)

    -- Fire legacy compatibility events (see event_bridge.lua for full mapping)
    TriggerEvent('galaxy:server:playerLoaded', source, gPlayer)

    -- Send full PlayerData to client
    TriggerClientEvent('galaxy:client:characterLoaded', source, gPlayer.PlayerData)
    TriggerClientEvent('galaxy:client:syncPlayerData',  source, gPlayer.PlayerData)

    print(('[GALAXY] Character loaded: %s (cid=%s) → source=%d'):format(
        gPlayer.PlayerData.name, citizenid, source))
end

--- Internal: save and remove a player from the registry.
---@param source number
local function UnloadPlayer(source)
    local gPlayer = Galaxy.Players[source]
    if not gPlayer then return end

    -- Save to DB
    gPlayer.Functions.Save()

    -- Fire events before removal
    TriggerEvent('galaxy:server:playerDropped', source, gPlayer)

    -- Clean up
    Galaxy.Players[source] = nil
    GlobalState:set('galaxy:playerCount', math.max(0, #GF.GetPlayers()), true)

    if Galaxy.Config.Debug then
        print(('[GALAXY] Player unloaded: source=%d'):format(source))
    end
end

-- ─── Network Events ───────────────────────────────────────────────────────────

-- Client selects or creates a character
RegisterNetEvent('galaxy:server:selectCharacter', function(citizenid)
    local source = source
    LoadCharacter(source, citizenid)
end)

-- Client creates a new character
RegisterNetEvent('galaxy:server:createCharacter', function(charinfo)
    local source  = source
    local license = GetLicense(source)
    if not license then return end

    -- Count existing chars
    local existing = Galaxy.DB.GetCharacters(license)
    if #existing >= Galaxy.Config.MaxCharacters then
        TriggerClientEvent('galaxy:client:notify', source, {
            description = ('Maximum characters (%d) reached.'):format(Galaxy.Config.MaxCharacters),
            type = 'error', duration = 5000,
        })
        return
    end

    local slot      = #existing + 1
    local citizenid = Galaxy.Player.GenerateCitizenId()

    -- Basic charinfo validation
    charinfo = {
        firstname   = tostring(charinfo.firstname or 'Unknown'):sub(1, 50),
        lastname    = tostring(charinfo.lastname  or 'Player'):sub(1, 50),
        birthdate   = tostring(charinfo.birthdate or '01-01-2000'):sub(1, 10),
        gender      = tonumber(charinfo.gender)   or 0,
        nationality = tostring(charinfo.nationality or 'USA'):sub(1, 50),
        phone       = tostring(charinfo.phone     or math.random(1000000, 9999999)):sub(1, 20),
        account     = ('US%08d'):format(math.random(0, 99999999)),
    }

    local ok = Galaxy.DB.CreateCharacter(license, slot, citizenid, charinfo)
    if not ok then
        TriggerClientEvent('galaxy:client:notify', source, {
            description = 'Failed to create character. Please try again.',
            type = 'error', duration = 5000,
        })
        return
    end

    LoadCharacter(source, citizenid)
end)

-- Client requests character list (for char select screen)
RegisterNetEvent('galaxy:server:requestCharacters', function()
    local source  = source
    local license = GetLicense(source)
    if not license then return end
    local chars = Galaxy.DB.GetCharacters(license)
    TriggerClientEvent('galaxy:client:receiveCharacters', source, chars)
end)

-- Client deletes a character
RegisterNetEvent('galaxy:server:deleteCharacter', function(citizenid)
    local source  = source
    local license = GetLicense(source)
    if not license then return end
    local row = Galaxy.DB.GetCharacter(citizenid)
    if not row or row.license ~= license then return end
    Galaxy.DB.DeleteCharacter(citizenid)
    TriggerClientEvent('galaxy:client:notify', source, {
        description = 'Character deleted.', type = 'success', duration = 3000
    })
    -- Re-send updated character list
    local chars = Galaxy.DB.GetCharacters(license)
    TriggerClientEvent('galaxy:client:receiveCharacters', source, chars)
end)

-- ─── FiveM Connection Hooks ───────────────────────────────────────────────────

AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    local source = source
    deferrals.defer()
    Citizen.Wait(0)
    deferrals.update(('[%s] Checking your details...'):format(Galaxy.Config.ServerName))

    local license = GetLicense(source)
    if not license then
        deferrals.done('[GALAXY] No Rockstar license detected. Please restart your client.')
        return
    end

    -- Check for existing ban (simple example — extend for a full ban system)
    local banned = Galaxy.DB.Single(
        "SELECT 1 FROM `galaxy_players` WHERE `license` = ? AND `banned` = 1 LIMIT 1",
        { license }
    )
    if banned then
        deferrals.done('[GALAXY] You are banned from this server.')
        return
    end

    deferrals.done()
end)

AddEventHandler('playerJoining', function()
    local source = source
    -- Small wait to ensure all identifiers are available
    SetTimeout(100, function()
        HandlePlayerConnecting(source)
    end)
end)

AddEventHandler('playerDropped', function(reason)
    local source = source
    UnloadPlayer(source)
end)

-- ─── Periodic auto-save ───────────────────────────────────────────────────────
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(5 * 60 * 1000)   -- every 5 minutes
        local saved = 0
        for _, gPlayer in pairs(Galaxy.Players) do
            pcall(gPlayer.Functions.Save)
            saved = saved + 1
        end
        if Galaxy.Config.Debug and saved > 0 then
            print(('[GALAXY] Auto-saved %d player(s).'):format(saved))
        end
    end
end)

-- ─── Admin commands ───────────────────────────────────────────────────────────
RegisterCommand('players', function(src, args)
    local count = 0
    for _ in pairs(Galaxy.Players) do count = count + 1 end
    local msg = ('[GALAXY] Online players: %d'):format(count)
    if src == 0 then
        print(msg)
    else
        TriggerClientEvent('galaxy:client:notify', src, { description = msg, type = 'inform' })
    end
end, false)

-- ─── Start salary timer ───────────────────────────────────────────────────────
Galaxy.Economy.StartSalaryTimer()

-- ─── Framework ready signal ───────────────────────────────────────────────────
Galaxy.Loaded = true
GlobalState:set('galaxy:ready', true, true)
TriggerEvent('galaxy:server:ready')

print('╔══════════════════════════════════════════════════╗')
print('║         GALAXY CORE — Universal Framework         ║')
print('║         v1.0.0 — All bridge layers loading...     ║')
print('╚══════════════════════════════════════════════════╝')
