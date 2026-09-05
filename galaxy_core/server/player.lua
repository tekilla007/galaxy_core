--[[
    GALAXY Core — Player Object Constructor (server/player.lua)
    Builds the unified GalaxyPlayer object with methods that work for both
    QBCore-style and ESX-style consumers.
--]]

Galaxy.Player = {}
local Player  = Galaxy.Player

-- ─── Citizen ID Generator ─────────────────────────────────────────────────────
local function RandomString(len)
    local charset = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local result  = {}
    for _ = 1, len do
        local idx = math.random(1, #charset)
        result[#result + 1] = charset:sub(idx, idx)
    end
    return table.concat(result)
end

--- Generate a unique citizen ID in the format "GAL-XXXXX-XXXXX"
---@return string
function Player.GenerateCitizenId()
    local prefix = Galaxy.Config.Prefix
    repeat
        local cid = ('%s-%s-%s'):format(prefix, RandomString(5), RandomString(5))
        local exists = Galaxy.DB.Single(
            'SELECT 1 FROM `galaxy_characters` WHERE `citizenid` = ? LIMIT 1',
            { cid }
        )
        if not exists then return cid end
    until false
end

-- ─── Default metadata template ────────────────────────────────────────────────
local function DefaultMetadata()
    return {
        hunger         = 100,
        thirst         = 100,
        stress         = 0,
        isdead         = false,
        inlaststand    = false,
        ishandcuffed   = false,
        tracker        = false,
        injail         = 0,
        jailitems      = {},
        status         = {},
        armor          = 0,
        bloodtype      = 'O+',
        dealerrep      = 0,
        craftingrep    = 0,
        callsign        = 'NONE',
        fingerprint    = '',
        inside         = {},
        licences = {
            driver   = false,
            weapon   = false,
            hunting  = false,
            business = false,
        },
        criminalrecord = {
            hasRecord = false,
            date      = nil,
        },
    }
end

-- ─── Build Job / Gang tables from config ──────────────────────────────────────
local function BuildJobTable(jobName, grade)
    local cfg   = Galaxy.Config.Jobs[jobName] or Galaxy.Config.Jobs['unemployed']
    local grade = tonumber(grade) or 0
    local gradeData = cfg.grades[grade] or cfg.grades[0]
    return {
        name         = jobName,
        label        = cfg.label,
        type         = cfg.type or '',
        payment      = gradeData.salary or 0,
        onduty       = (jobName ~= 'unemployed'),
        isboss       = gradeData.isboss or false,
        grade = {
            name  = gradeData.label or 'Unknown',
            level = grade,
        },
        -- ESX compat aliases
        grade_name   = gradeData.label or 'Unknown',
        grade_label  = gradeData.label or 'Unknown',
        salary       = gradeData.salary or 0,
    }
end

local function BuildGangTable(gangName, grade)
    local cfg   = Galaxy.Config.Gangs[gangName] or Galaxy.Config.Gangs['none']
    local grade = tonumber(grade) or 0
    local gradeData = cfg.grades[grade] or cfg.grades[0]
    return {
        name   = gangName,
        label  = cfg.label,
        isboss = gradeData.isboss or false,
        grade = {
            name  = gradeData.label or 'none',
            level = grade,
        },
    }
end

-- ─── Parse DB row into a clean PlayerData table ───────────────────────────────
local function ParseCharacterRow(row, source, license)
    local charinfo  = type(row.charinfo)  == 'string' and json.decode(row.charinfo)  or row.charinfo  or {}
    local money     = type(row.money)     == 'string' and json.decode(row.money)     or row.money     or {}
    local accounts  = type(row.accounts)  == 'string' and json.decode(row.accounts)  or row.accounts  or {}
    local metadata  = type(row.metadata)  == 'string' and json.decode(row.metadata)  or row.metadata  or {}
    local position  = type(row.position)  == 'string' and json.decode(row.position)  or row.position  or {}
    local jobName   = row.job       or 'unemployed'
    local jobGrade  = row.job_grade or 0
    local gangName  = row.gang      or 'none'
    local gangGrade = row.gang_grade or 0

    -- Merge missing metadata keys with defaults
    local defaultMeta = DefaultMetadata()
    for k, v in pairs(defaultMeta) do
        if metadata[k] == nil then metadata[k] = v end
    end

    -- Normalise money table (ensure all types exist)
    money.cash        = money.cash        or 0
    money.bank        = money.bank        or 0
    money.black_money = money.black_money or 0
    money.crypto      = money.crypto      or 0

    -- Normalise ESX accounts array
    if #accounts == 0 then
        accounts = {
            { name = 'money',       label = 'Cash',        money = money.cash        },
            { name = 'bank',        label = 'Bank',        money = money.bank        },
            { name = 'black_money', label = 'Black Money', money = money.black_money },
        }
    end

    local pos = vector4(
        tonumber(position.x) or Galaxy.Config.DefaultSpawn.x,
        tonumber(position.y) or Galaxy.Config.DefaultSpawn.y,
        tonumber(position.z) or Galaxy.Config.DefaultSpawn.z,
        tonumber(position.w) or Galaxy.Config.DefaultSpawn.w
    )

    return {
        -- Identity
        source      = source,
        license     = license,
        identifier  = license,    -- ESX compat
        citizenid   = row.citizenid,
        cid         = row.slot or 1,
        name        = (charinfo.firstname or '') .. ' ' .. (charinfo.lastname or ''),

        -- Character data
        charinfo    = charinfo,
        money       = money,
        accounts    = accounts,
        job         = BuildJobTable(jobName, jobGrade),
        gang        = BuildGangTable(gangName, gangGrade),
        metadata    = metadata,
        position    = pos,

        -- Group / permissions
        group       = 'user',  -- set from galaxy_players.group after load

        -- Items handled by ox_inventory or builtin bridge separately
        items       = {},
        inventory   = {},
        maxWeight   = Galaxy.Config.MaxWeight,
        weight      = 0,

        -- Loadout (weapons)
        loadout     = {},
    }
end

-- ─── GalaxyPlayer Object Factory ──────────────────────────────────────────────

---@param source number    player server ID
---@param data   table     raw DB row from galaxy_characters
---@param license string
---@return table GalaxyPlayer
function Player.New(source, data, license)
    local PlayerData = ParseCharacterRow(data, source, license)

    local self = { PlayerData = PlayerData }

    -- ── Internal state sync helper ────────────────────────────────────────────
    local function SyncToClient()
        TriggerClientEvent('galaxy:client:syncPlayerData', source, PlayerData)
        -- Also fire QBCore & ESX client events so third-party scripts update
        TriggerClientEvent('QBCore:Player:SetPlayerData',  source, PlayerData)
        TriggerClientEvent('esx:setPlayerData',            source, 'job',     PlayerData.job)
        TriggerClientEvent('esx:setPlayerData',            source, 'accounts',PlayerData.accounts)
    end

    -- ─── Money Functions ─────────────────────────────────────────────────────
    self.Functions = {}
    local F = self.Functions

    function F.GetMoney(moneyType)
        return PlayerData.money[moneyType] or 0
    end

    function F.AddMoney(moneyType, amount, reason)
        amount = math.floor(tonumber(amount) or 0)
        if amount <= 0 then return false end
        if not PlayerData.money[moneyType] then return false end

        PlayerData.money[moneyType] = PlayerData.money[moneyType] + amount

        -- Keep ESX accounts array in sync
        for _, acc in ipairs(PlayerData.accounts) do
            if acc.name == moneyType or (moneyType == 'cash' and acc.name == 'money') then
                acc.money = acc.money + amount
                break
            end
        end

        SyncToClient()
        TriggerEvent('galaxy:server:moneyChange', source, moneyType, 'add', amount, reason)
        return true
    end

    function F.RemoveMoney(moneyType, amount, reason)
        amount = math.floor(tonumber(amount) or 0)
        if amount <= 0 then return false end
        if not PlayerData.money[moneyType] then return false end
        if PlayerData.money[moneyType] < amount then return false end

        PlayerData.money[moneyType] = PlayerData.money[moneyType] - amount

        for _, acc in ipairs(PlayerData.accounts) do
            if acc.name == moneyType or (moneyType == 'cash' and acc.name == 'money') then
                acc.money = math.max(0, acc.money - amount)
                break
            end
        end

        SyncToClient()
        TriggerEvent('galaxy:server:moneyChange', source, moneyType, 'remove', amount, reason)
        return true
    end

    function F.SetMoney(moneyType, amount)
        amount = math.floor(tonumber(amount) or 0)
        if amount < 0 then return false end
        if not PlayerData.money[moneyType] then return false end
        PlayerData.money[moneyType] = amount

        for _, acc in ipairs(PlayerData.accounts) do
            if acc.name == moneyType or (moneyType == 'cash' and acc.name == 'money') then
                acc.money = amount
                break
            end
        end

        SyncToClient()
        return true
    end

    -- ESX-style account accessors
    function F.GetAccount(accountName)
        local mapped = accountName == 'money' and 'cash' or accountName
        for _, acc in ipairs(PlayerData.accounts) do
            if acc.name == accountName then
                return acc
            end
        end
        return { name = accountName, label = accountName, money = 0 }
    end

    function F.AddAccountMoney(accountName, amount)
        local mapped = accountName == 'money' and 'cash' or accountName
        return F.AddMoney(mapped, amount, 'account_add')
    end

    function F.RemoveAccountMoney(accountName, amount)
        local mapped = accountName == 'money' and 'cash' or accountName
        return F.RemoveMoney(mapped, amount, 'account_remove')
    end

    function F.SetAccountMoney(accountName, amount)
        local mapped = accountName == 'money' and 'cash' or accountName
        return F.SetMoney(mapped, amount)
    end

    -- ─── Job / Gang ───────────────────────────────────────────────────────────
    function F.SetJob(jobName, grade)
        grade = tonumber(grade) or 0
        local jobCfg = Galaxy.Config.Jobs[jobName]
        if not jobCfg then
            print(('[GALAXY/Player] Unknown job: %s'):format(jobName))
            return false
        end
        local lastJob = PlayerData.job
        PlayerData.job = BuildJobTable(jobName, grade)
        SyncToClient()
        TriggerEvent('galaxy:server:setJob', source, PlayerData.job, lastJob)
        -- Legacy events
        TriggerEvent('QBCore:Server:SetJob', source, PlayerData.job, lastJob)
        TriggerEvent('esx:setJob',           source, PlayerData.job, lastJob)
        return true
    end

    function F.SetGang(gangName, grade)
        grade = tonumber(grade) or 0
        local gangCfg = Galaxy.Config.Gangs[gangName]
        if not gangCfg then
            print(('[GALAXY/Player] Unknown gang: %s'):format(gangName))
            return false
        end
        local lastGang = PlayerData.gang
        PlayerData.gang = BuildGangTable(gangName, grade)
        SyncToClient()
        TriggerEvent('galaxy:server:setGang', source, PlayerData.gang, lastGang)
        TriggerEvent('QBCore:Server:SetGang', source, PlayerData.gang, lastGang)
        return true
    end

    -- ─── Metadata ─────────────────────────────────────────────────────────────
    function F.GetMetaData(key)
        return PlayerData.metadata[key]
    end

    function F.SetMetaData(key, value)
        PlayerData.metadata[key] = value
        SyncToClient()
    end

    -- ─── State bag helpers ────────────────────────────────────────────────────
    function F.SetState(key, value, replicated)
        Player(source).state:set(key, value, replicated ~= false)
    end

    function F.GetState(key)
        return Player(source).state[key]
    end

    -- ─── Inventory wrappers (delegate to backend) ─────────────────────────────
    function F.AddItem(itemName, amount, slot, metadata)
        if Galaxy.Config.InventorySystem == 'ox' then
            if GetResourceState('ox_inventory') == 'started' then
                return exports.ox_inventory:AddItem(source, itemName, amount, metadata, slot)
            end
        end
        -- Builtin fallback
        return Galaxy.Inventory and Galaxy.Inventory.AddItem(source, itemName, amount, slot, metadata)
    end

    function F.RemoveItem(itemName, amount, slot)
        if Galaxy.Config.InventorySystem == 'ox' then
            if GetResourceState('ox_inventory') == 'started' then
                return exports.ox_inventory:RemoveItem(source, itemName, amount, nil, slot)
            end
        end
        return Galaxy.Inventory and Galaxy.Inventory.RemoveItem(source, itemName, amount, slot)
    end

    function F.GetItemByName(itemName)
        if Galaxy.Config.InventorySystem == 'ox' then
            if GetResourceState('ox_inventory') == 'started' then
                return exports.ox_inventory:GetItem(source, itemName, nil, false)
            end
        end
        return nil
    end

    function F.HasItem(itemName, amount)
        local item = F.GetItemByName(itemName)
        if not item then return false end
        return item.count >= (amount or 1)
    end

    -- ─── Utility ──────────────────────────────────────────────────────────────
    function F.GetPlayerData()
        return PlayerData
    end

    function F.Save()
        Galaxy.DB.SaveCharacter({
            citizenid   = PlayerData.citizenid,
            charinfo    = PlayerData.charinfo,
            money       = PlayerData.money,
            accounts    = PlayerData.accounts,
            job         = PlayerData.job.name,
            job_grade   = PlayerData.job.grade.level,
            gang        = PlayerData.gang.name,
            gang_grade  = PlayerData.gang.grade.level,
            metadata    = PlayerData.metadata,
            position    = PlayerData.position,
        })
    end

    function F.Kick(reason)
        DropPlayer(source, reason or 'Kicked by server.')
    end

    function F.Notify(text, notifyType, duration)
        TriggerClientEvent('galaxy:client:notify', source, {
            description = text,
            type        = notifyType or 'inform',
            duration    = duration or 5000,
        })
    end

    -- ESX xPlayer compat alias
    function F.triggerEvent(eventName, ...)
        TriggerClientEvent(eventName, source, ...)
    end

    function F.showNotification(msg)
        F.Notify(msg, 'inform', 5000)
    end

    -- Allow reading common ESX fields directly
    self.identifier = PlayerData.identifier
    self.source     = PlayerData.source
    self.name       = PlayerData.name
    self.group      = PlayerData.group
    self.job        = PlayerData.job     -- live reference; stays in sync via SetJob
    self.job2       = PlayerData.job     -- ESX secondary job compat alias
    self.accounts   = PlayerData.accounts
    self.inventory  = PlayerData.inventory
    self.metadata   = PlayerData.metadata
    self.coords     = PlayerData.position
    self.maxWeight  = PlayerData.maxWeight
    self.weight     = PlayerData.weight
    self.loadout    = PlayerData.loadout

    return self
end

print('[GALAXY] Player object module loaded.')
