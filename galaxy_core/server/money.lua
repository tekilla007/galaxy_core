--[[
    GALAXY Core — Money & Economy System (server/money.lua)
    Handles salary payouts, the usable-item registry, and economy-level helpers.
    Builds on top of the Player object (player.lua must load first).
--]]

Galaxy.Economy = {}
local Economy = Galaxy.Economy

-- ─── Usable Item Registry ─────────────────────────────────────────────────────
-- Table of { [itemName] = callback(source) }
local UsableItems = {}

--- Register an item as usable so any framework can call UseItem.
---@param itemName string
---@param callback function  receives (source) when item is used
function Economy.RegisterUsableItem(itemName, callback)
    if type(callback) ~= 'function' then
        print(('[GALAXY/Economy] RegisterUsableItem: callback for "%s" is not a function'):format(itemName))
        return
    end
    UsableItems[itemName] = callback
    if Galaxy.Config.Debug then
        print(('[GALAXY/Economy] Registered usable item: %s'):format(itemName))
    end
end

--- Trigger the use callback for an item. Validates item ownership first.
---@param source number
---@param itemName string
---@param itemData table|nil  optional item metadata to pass to callback
function Economy.UseItem(source, itemName, itemData)
    local cb = UsableItems[itemName]
    if not cb then
        print(('[GALAXY/Economy] UseItem: no handler registered for "%s"'):format(itemName))
        return
    end
    cb(source, itemData or { name = itemName })
end

--- Check if an item has a registered use callback.
---@param itemName string
---@return boolean
function Economy.CanUseItem(itemName)
    return UsableItems[itemName] ~= nil
end

--- Return the full usable items table (read-only safe).
function Economy.GetUsableItems()
    return UsableItems
end

-- ─── Salary System ────────────────────────────────────────────────────────────
local SalaryTimer = nil
local SALARY_INTERVAL = 30 * 60 * 1000  -- 30 minutes in ms

local function PaySalaries()
    local players = Galaxy.Functions.GetQBPlayers()
    for _, gPlayer in pairs(players) do
        local salary = gPlayer.PlayerData.job.payment or 0
        if salary > 0 then
            local paid = gPlayer.Functions.AddMoney('bank', salary, 'salary')
            if paid then
                gPlayer.Functions.Notify(
                    ('💰 Salary paid: $%d'):format(salary),
                    'success', 5000
                )
            end
        end
    end
end

--- Start the salary payout loop.
function Economy.StartSalaryTimer()
    if SalaryTimer then return end
    SalaryTimer = true
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(SALARY_INTERVAL)
            PaySalaries()
        end
    end)
    print('[GALAXY/Economy] Salary timer started (every 30 minutes).')
end

-- ─── Server-side item use handler ─────────────────────────────────────────────
-- Client requests an item use → server validates ownership → calls callback
RegisterNetEvent('galaxy:server:useItem', function(itemName)
    local source = source
    local player = Galaxy.Functions.GetPlayer(source)
    if not player then return end

    -- Validate player actually has the item
    if not player.Functions.HasItem(itemName, 1) then
        player.Functions.Notify('You do not have that item.', 'error', 3000)
        return
    end

    Economy.UseItem(source, itemName)
end)

-- ─── Admin: give money command ─────────────────────────────────────────────────
RegisterCommand('givemoney', function(src, args, rawCommand)
    if src ~= 0 and not IsPlayerAceAllowed(tostring(src), 'galaxy.admin') then
        if src ~= 0 then
            TriggerClientEvent('galaxy:client:notify', src, {
                description = 'No permission.', type = 'error', duration = 3000
            })
        end
        return
    end

    local targetSrc  = tonumber(args[1])
    local moneyType  = tostring(args[2] or 'cash')
    local amount     = tonumber(args[3])

    if not targetSrc or not amount then
        print('[GALAXY] Usage: /givemoney [source] [cash|bank|black_money] [amount]')
        return
    end

    local target = Galaxy.Functions.GetPlayer(targetSrc)
    if not target then
        print('[GALAXY] Player not found: ' .. targetSrc)
        return
    end

    target.Functions.AddMoney(moneyType, amount, 'admin_give')
    print(('[GALAXY/Admin] Gave $%d (%s) to %s'):format(amount, moneyType, target.PlayerData.name))
end, false)

print('[GALAXY] Economy module loaded.')
