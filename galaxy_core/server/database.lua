--[[
    GALAXY Core — Database Abstraction Layer (server/database.lua)
    Wraps oxmysql with a clean, promise-based API.
    All queries go through this module so the DB backend can be swapped without
    touching game logic.
--]]

Galaxy.DB = {}
local DB = Galaxy.DB

-- ─── Internal logger ─────────────────────────────────────────────────────────
local function Log(level, msg, ...)
    if Galaxy.Config.LogLevel == 'debug' or level ~= 'debug' then
        print(('[GALAXY/DB][%s] %s'):format(level:upper(), msg:format(...)))
    end
end

-- ─── Query Helpers ────────────────────────────────────────────────────────────

--- Execute a SELECT query returning all rows.
---@param query string
---@param params table|nil
---@return table  rows (may be empty table, never nil)
function DB.Query(query, params)
    local result = MySQL.query.await(query, params or {})
    return result or {}
end

--- Execute a SELECT query returning the first row only.
---@param query string
---@param params table|nil
---@return table|nil  row or nil if no results
function DB.Single(query, params)
    local result = MySQL.single.await(query, params or {})
    return result
end

--- Execute an INSERT/UPDATE/DELETE returning affected rows or insert ID.
---@param query string
---@param params table|nil
---@return number
function DB.Execute(query, params)
    local result = MySQL.update.await(query, params or {})
    return result or 0
end

--- Execute an INSERT returning the auto-increment ID.
---@param query string
---@param params table|nil
---@return number insertId
function DB.Insert(query, params)
    local result = MySQL.insert.await(query, params or {})
    return result or 0
end

--- Execute multiple queries in a single transaction.
---@param queries table  array of { query=string, values=table }
---@return boolean success
function DB.Transaction(queries)
    local success = MySQL.transaction.await(queries)
    return success == true
end

--- Scalar: return a single value from the first column of the first row.
---@param query string
---@param params table|nil
---@return any
function DB.Scalar(query, params)
    local result = MySQL.scalar.await(query, params or {})
    return result
end

-- ─── Character / Player Queries ───────────────────────────────────────────────

--- Load or create a player record from the galaxy_players table.
---@param license string
---@param name string
---@return table playerRow
function DB.GetOrCreatePlayer(license, name)
    local row = DB.Single(
        'SELECT * FROM `galaxy_players` WHERE `license` = ? LIMIT 1',
        { license }
    )
    if not row then
        DB.Execute(
            'INSERT INTO `galaxy_players` (`license`, `name`, `lastSeen`) VALUES (?, ?, NOW())',
            { license, name }
        )
        row = DB.Single(
            'SELECT * FROM `galaxy_players` WHERE `license` = ? LIMIT 1',
            { license }
        )
        Log('info', 'New player registered: %s (%s)', name, license)
    else
        DB.Execute(
            'UPDATE `galaxy_players` SET `name` = ?, `lastSeen` = NOW() WHERE `license` = ?',
            { name, license }
        )
    end
    return row
end

--- Fetch all characters belonging to a license.
---@param license string
---@return table characters
function DB.GetCharacters(license)
    return DB.Query(
        'SELECT * FROM `galaxy_characters` WHERE `license` = ? AND `deleted` = 0 ORDER BY `slot` ASC',
        { license }
    )
end

--- Fetch a specific character by citizenid.
---@param citizenid string
---@return table|nil
function DB.GetCharacter(citizenid)
    return DB.Single(
        'SELECT * FROM `galaxy_characters` WHERE `citizenid` = ? AND `deleted` = 0 LIMIT 1',
        { citizenid }
    )
end

--- Fetch a character by identifier (legacy ESX lookup).
---@param identifier string
---@return table|nil
function DB.GetCharacterByIdentifier(identifier)
    return DB.Single(
        'SELECT * FROM `galaxy_characters` WHERE `license` = ? AND `deleted` = 0 LIMIT 1',
        { identifier }
    )
end

--- Fetch a character by phone number (stored in charinfo JSON).
---@param phone string
---@return table|nil
function DB.GetCharacterByPhone(phone)
    return DB.Single(
        "SELECT * FROM `galaxy_characters` WHERE JSON_EXTRACT(`charinfo`, '$.phone') = ? AND `deleted` = 0 LIMIT 1",
        { phone }
    )
end

--- Save all mutable character data back to the database.
---@param data table  must include citizenid
function DB.SaveCharacter(data)
    DB.Execute([[
        UPDATE `galaxy_characters`
        SET
            `charinfo`  = ?,
            `money`     = ?,
            `accounts`  = ?,
            `job`       = ?,
            `job_grade` = ?,
            `gang`      = ?,
            `gang_grade`= ?,
            `metadata`  = ?,
            `position`  = ?,
            `lastSeen`  = NOW()
        WHERE `citizenid` = ?
    ]], {
        json.encode(data.charinfo),
        json.encode(data.money),
        json.encode(data.accounts),
        data.job,
        data.job_grade,
        data.gang,
        data.gang_grade,
        json.encode(data.metadata),
        json.encode(data.position),
        data.citizenid,
    })
end

--- Create a brand-new character row.
---@param license string
---@param slot number      character slot (1–Config.MaxCharacters)
---@param citizenid string newly generated ID
---@param charinfo table
---@return boolean
function DB.CreateCharacter(license, slot, citizenid, charinfo)
    local money = {
        cash        = Galaxy.Config.StartingCash,
        bank        = Galaxy.Config.StartingBank,
        black_money = Galaxy.Config.StartingBlackMoney,
        crypto      = 0,
    }
    local accounts = {
        { name = 'money',        label = 'Cash',        money = Galaxy.Config.StartingCash  },
        { name = 'bank',         label = 'Bank',        money = Galaxy.Config.StartingBank  },
        { name = 'black_money',  label = 'Black Money', money = 0 },
    }
    local defaultJob   = 'unemployed'
    local defaultGang  = 'none'
    local defaultMeta  = {
        hunger = 100, thirst = 100, stress = 0,
        isdead = false, inlaststand = false, ishandcuffed = false,
        injail = 0, armor = 0, bloodtype = 'O+',
        licences = { driver = false, weapon = false },
        criminalrecord = { hasRecord = false, date = nil },
    }
    local startPos = Galaxy.Config.NewPlayerSpawn

    local id = DB.Insert([[
        INSERT INTO `galaxy_characters`
            (`license`, `slot`, `citizenid`, `charinfo`, `money`, `accounts`,
             `job`, `job_grade`, `gang`, `gang_grade`, `metadata`, `position`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        license, slot, citizenid,
        json.encode(charinfo),
        json.encode(money),
        json.encode(accounts),
        defaultJob, 0,
        defaultGang, 0,
        json.encode(defaultMeta),
        json.encode({ x = startPos.x, y = startPos.y, z = startPos.z, w = startPos.w }),
    })
    return id > 0
end

--- Soft-delete a character.
---@param citizenid string
function DB.DeleteCharacter(citizenid)
    DB.Execute(
        'UPDATE `galaxy_characters` SET `deleted` = 1 WHERE `citizenid` = ?',
        { citizenid }
    )
end

-- ─── Inventory (only used when Config.InventorySystem == 'builtin') ───────────

function DB.GetInventory(citizenid)
    return DB.Query(
        'SELECT * FROM `galaxy_inventory` WHERE `citizenid` = ?',
        { citizenid }
    )
end

function DB.SaveInventorySlot(citizenid, slot, name, count, metadata)
    if not name or count <= 0 then
        DB.Execute('DELETE FROM `galaxy_inventory` WHERE `citizenid` = ? AND `slot` = ?', { citizenid, slot })
    else
        DB.Execute([[
            INSERT INTO `galaxy_inventory` (`citizenid`, `slot`, `name`, `count`, `metadata`)
            VALUES (?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE `name` = ?, `count` = ?, `metadata` = ?
        ]], { citizenid, slot, name, count, json.encode(metadata or {}), name, count, json.encode(metadata or {}) })
    end
end

-- ─── Ready signal ─────────────────────────────────────────────────────────────
Log('info', 'Database layer loaded (backend: oxmysql)')
