fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name        'galaxy_core'
author      'GALAXY Development Team'
description 'Universal FiveM Framework — Standalone core with QBCore, QBX, and ESX compatibility bridges.'
version     '1.0.0'
url         'https://github.com/galaxy-framework/galaxy_core'

-- ─── Shared (both server and client) ──────────────────────────────────────────
shared_scripts {
    '@ox_lib/init.lua',     -- ox_lib must start before galaxy_core
    'config/config.lua',
    'config/jobs.lua',
    'config/items.lua',
}

-- ─── Server-side files ────────────────────────────────────────────────────────
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/database.lua',
    'server/player.lua',
    'server/money.lua',
    'server/callbacks.lua',
    'server/core.lua',      -- must load last: uses Player & DB layers
    -- Bridge layer — spoofs legacy globals AFTER core is ready
    'bridge/qbcore_bridge.lua',
    'bridge/esx_bridge.lua',
    'bridge/event_bridge.lua',
}

-- ─── Client-side files ────────────────────────────────────────────────────────
client_scripts {
    'client/core.lua',
    'client/bridge_qb.lua',
    'client/bridge_esx.lua',
}

-- ─── Exports: consumed by third-party scripts ─────────────────────────────────
-- QBCore / QBX style
server_export 'GetCoreObject'
server_export 'GetPlayer'
server_export 'GetPlayers'
server_export 'GetQBPlayers'
server_export 'GetPlayerByCitizenId'
server_export 'GetPlayerByIdentifier'
server_export 'GetPlayerByPhone'
server_export 'GetOfflinePlayer'

-- ESX style
server_export 'getSharedObject'
server_export 'GetPlayerFromId'
server_export 'GetPlayerFromIdentifier'
server_export 'GetExtendedPlayers'
server_export 'RegisterUsableItem'
server_export 'UseItem'

-- Shared/utility
server_export 'GetJobs'
server_export 'GetItems'
server_export 'AddItem'

-- Client exports
client_export 'GetCoreObject'
client_export 'GetPlayerData'

-- ─── Dependency declarations ──────────────────────────────────────────────────
dependencies {
    'ox_lib',
    'oxmysql',
}

-- ─── Convar ACE declarations ──────────────────────────────────────────────────
convar_policy {
    'galaxy_defaultStartingCash',
    'galaxy_defaultStartingBank',
    'galaxy_multiCharacter',
    'galaxy_inventorySystem',
}
