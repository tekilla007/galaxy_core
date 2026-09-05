--[[
    GALAXY Core — Item Registry
    Define all usable and carryable items here.
    This table is shared between server and client.

    Structure:
        Items[itemName] = {
            name   = string,          -- must match key
            label  = string,          -- human-readable display name
            weight = number,          -- weight in grams
            type   = string,          -- 'item' | 'weapon' | 'ammo'
            image  = string|nil,      -- filename in html/images/ folder
            unique = bool|nil,        -- if true, item cannot stack
            useable = bool|nil,       -- if true, item can be "used" from inventory
            shouldClose = bool|nil,   -- close inventory on use
            combinable = nil,         -- future: crafting combinator
            description = string|nil, -- tooltip text
        }
--]]

Galaxy.Config.Items = {

    -- ── Money (physical) ─────────────────────────────────────────────────────
    ['money'] = {
        name    = 'money',
        label   = 'Cash',
        weight  = 0,
        type    = 'item',
        image   = 'money.png',
        unique  = false,
    },
    ['black_money'] = {
        name    = 'black_money',
        label   = 'Dirty Money',
        weight  = 0,
        type    = 'item',
        image   = 'black_money.png',
        unique  = false,
    },

    -- ── Food & Drinks ─────────────────────────────────────────────────────────
    ['bread'] = {
        name        = 'bread',
        label       = 'Bread',
        weight      = 150,
        type        = 'item',
        useable     = true,
        shouldClose = true,
        description = 'Eat to restore hunger.',
    },
    ['water'] = {
        name        = 'water',
        label       = 'Water Bottle',
        weight      = 500,
        type        = 'item',
        useable     = true,
        shouldClose = true,
        description = 'Drink to restore thirst.',
    },
    ['sandwich'] = {
        name        = 'sandwich',
        label       = 'Sandwich',
        weight      = 200,
        type        = 'item',
        useable     = true,
        shouldClose = true,
    },
    ['taco'] = {
        name        = 'taco',
        label       = 'Taco',
        weight      = 100,
        type        = 'item',
        useable     = true,
        shouldClose = true,
    },

    -- ── Medical ───────────────────────────────────────────────────────────────
    ['firstaid'] = {
        name        = 'firstaid',
        label       = 'First Aid Kit',
        weight      = 500,
        type        = 'item',
        useable     = true,
        unique      = false,
        shouldClose = true,
        description = 'Basic medical supplies to patch wounds.',
    },
    ['bandage'] = {
        name        = 'bandage',
        label       = 'Bandage',
        weight      = 100,
        type        = 'item',
        useable     = true,
        shouldClose = false,
    },
    ['medikit'] = {
        name        = 'medikit',
        label       = 'Medikit',
        weight      = 1000,
        type        = 'item',
        useable     = true,
        unique      = false,
        shouldClose = true,
    },
    ['armor'] = {
        name        = 'armor',
        label       = 'Body Armor',
        weight      = 1500,
        type        = 'item',
        useable     = true,
        shouldClose = true,
    },

    -- ── Tools ─────────────────────────────────────────────────────────────────
    ['lockpick'] = {
        name        = 'lockpick',
        label       = 'Lockpick',
        weight      = 100,
        type        = 'item',
        useable     = true,
        unique      = false,
    },
    ['advancedlockpick'] = {
        name        = 'advancedlockpick',
        label       = 'Advanced Lockpick',
        weight      = 200,
        type        = 'item',
        useable     = true,
        unique      = false,
    },
    ['repairkit'] = {
        name        = 'repairkit',
        label       = 'Repair Kit',
        weight      = 2000,
        type        = 'item',
        useable     = true,
        shouldClose = true,
    },
    ['screwdriver'] = {
        name    = 'screwdriver',
        label   = 'Screwdriver',
        weight  = 250,
        type    = 'item',
        useable = false,
    },

    -- ── Drugs ─────────────────────────────────────────────────────────────────
    ['weed_seed'] = {
        name    = 'weed_seed',
        label   = 'Weed Seed',
        weight  = 10,
        type    = 'item',
        useable = false,
    },
    ['weed'] = {
        name        = 'weed',
        label       = 'Marijuana',
        weight      = 30,
        type        = 'item',
        useable     = true,
        shouldClose = false,
    },
    ['coke'] = {
        name        = 'coke',
        label       = 'Cocaine',
        weight      = 30,
        type        = 'item',
        useable     = true,
        shouldClose = false,
    },
    ['meth'] = {
        name        = 'meth',
        label       = 'Methamphetamine',
        weight      = 30,
        type        = 'item',
        useable     = true,
        shouldClose = false,
    },

    -- ── Documents ─────────────────────────────────────────────────────────────
    ['id_card'] = {
        name        = 'id_card',
        label       = 'ID Card',
        weight      = 10,
        type        = 'item',
        useable     = true,
        unique      = true,
        shouldClose = false,
        description = 'Your government-issued identification card.',
    },
    ['driver_license'] = {
        name        = 'driver_license',
        label       = "Driver's License",
        weight      = 10,
        type        = 'item',
        useable     = true,
        unique      = true,
        shouldClose = false,
    },
    ['weapon_license'] = {
        name        = 'weapon_license',
        label       = 'Weapon License',
        weight      = 10,
        type        = 'item',
        useable     = true,
        unique      = true,
        shouldClose = false,
    },

    -- ── Electronics ───────────────────────────────────────────────────────────
    ['phone'] = {
        name    = 'phone',
        label   = 'Phone',
        weight  = 200,
        type    = 'item',
        useable = true,
        unique  = true,
    },
    ['radio'] = {
        name    = 'radio',
        label   = 'Radio',
        weight  = 500,
        type    = 'item',
        useable = true,
        unique  = false,
    },

    -- ── Ammo ──────────────────────────────────────────────────────────────────
    ['pistol_ammo'] = {
        name   = 'pistol_ammo',
        label  = 'Pistol Ammo',
        weight = 10,
        type   = 'ammo',
    },
    ['rifle_ammo'] = {
        name   = 'rifle_ammo',
        label  = 'Rifle Ammo',
        weight = 20,
        type   = 'ammo',
    },
    ['shotgun_ammo'] = {
        name   = 'shotgun_ammo',
        label  = 'Shotgun Shells',
        weight = 30,
        type   = 'ammo',
    },
}
