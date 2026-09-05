--[[
    GALAXY Core — Main Configuration
    Adjust these values to match your server's needs.
    This file is shared between server and client contexts.
--]]

Galaxy = Galaxy or {}
Galaxy.Config = {}

local Config = Galaxy.Config

-- ─── Identity ─────────────────────────────────────────────────────────────────
Config.Prefix       = 'GAL'     -- citizen ID prefix  → e.g. "GAL-ABCDE-12345"
Config.ServerName   = 'GALAXY'  -- used in notifications & logs
Config.Locale       = 'en'      -- default locale (for ox_lib locale)
Config.Timezone     = 'UTC'

-- ─── Multi-Character ──────────────────────────────────────────────────────────
-- true  = players can have up to Config.MaxCharacters characters (QBX style)
-- false = one character per identifier (ESX style)
Config.MultiCharacter = true
Config.MaxCharacters  = 3

-- ─── Starting Economy ─────────────────────────────────────────────────────────
Config.StartingCash       = 500
Config.StartingBank       = 5000
Config.StartingBlackMoney = 0

-- ─── Money Account Names (mirrors ESX "accounts" + QBCore "money" types) ──────
-- These names must be consistent across scripts.
Config.MoneyTypes = {
    'cash',
    'bank',
    'black_money',
    'crypto',       -- optional, can be ignored by scripts that don't use it
}

-- Maximum carry weight (used by built-in inventory bridge)
Config.MaxWeight = 120000  -- grams (matches ox_inventory default)

-- ─── Inventory Backend ────────────────────────────────────────────────────────
-- 'ox'      = delegates all item management to ox_inventory (recommended)
-- 'builtin' = GALAXY's built-in lightweight inventory
Config.InventorySystem = 'ox'

-- ─── Spawn & Character ────────────────────────────────────────────────────────
Config.DefaultSpawn = vector4(-269.4, -955.3, 31.2, 205.0)   -- LSIA road

-- Wipe player's position to default spawn when they haven't played before
Config.NewPlayerSpawn = vector4(-269.4, -955.3, 31.2, 205.0)

-- ─── Death & Respawn ──────────────────────────────────────────────────────────
Config.RespawnPosition = vector4(297.4, -584.2, 43.3, 165.0)   -- Pillbox hospital
Config.DeathTimer      = 300   -- seconds before forced respawn (0 = no forced respawn)

-- ─── Permission Groups ────────────────────────────────────────────────────────
-- Maps Galaxy groups to ACE groups for txAdmin/server.cfg
Config.Groups = {
    user       = 0,
    vip        = 1,
    moderator  = 2,
    admin      = 3,
    superadmin = 4,
    god        = 5,
}

-- ─── Logging ──────────────────────────────────────────────────────────────────
Config.LogLevel = 'info'  -- 'debug' | 'info' | 'warn' | 'error'

-- If true, sends structured logs to the server console for each player event
Config.VerboseLogs = false

-- ─── Bridge Compatibility Flags ───────────────────────────────────────────────
-- Enable/disable each legacy compatibility bridge.
-- Disabling unused bridges saves a trivial amount of RAM but aids debugging.
Config.Bridges = {
    QBCore = true,   -- spoof QBCore + QBX globals & exports
    ESX    = true,   -- spoof ESX globals & exports
}

-- ─── Callbacks ────────────────────────────────────────────────────────────────
Config.CallbackTimeout = 10000   -- ms before a pending callback is considered dead

-- ─── OneSync ──────────────────────────────────────────────────────────────────
-- Set this to true when your server has OneSync enabled (recommended)
Config.OneSync = true

-- ─── Debug ────────────────────────────────────────────────────────────────────
Config.Debug = false
