--[[
    GALAXY Core — Job Definitions
    Add or modify jobs here. Each job entry is shared between server and client.
    Grade 0 is always the lowest/default grade.

    Structure:
        Jobs[jobName] = {
            label  = string,         -- Display name
            type   = string|nil,     -- Optional type tag (e.g. 'leo', 'ems', 'government')
            grades = {
                [0] = { label = string, salary = number },
                [1] = { label = string, salary = number },
                ...
            },
        }
--]]

Galaxy.Config.Jobs = {

    -- ── Unemployed (default) ─────────────────────────────────────────────────
    ['unemployed'] = {
        label = 'Unemployed',
        grades = {
            [0] = { label = 'Civilian',  salary = 0 },
        },
    },

    -- ── Law Enforcement ──────────────────────────────────────────────────────
    ['police'] = {
        label  = 'Law Enforcement',
        type   = 'leo',
        grades = {
            [0] = { label = 'Recruit',         salary = 200 },
            [1] = { label = 'Officer',         salary = 350 },
            [2] = { label = 'Senior Officer',  salary = 450 },
            [3] = { label = 'Sergeant',        salary = 550 },
            [4] = { label = 'Lieutenant',      salary = 650 },
            [5] = { label = 'Captain',         salary = 750 },
            [6] = { label = 'Deputy Chief',    salary = 900 },
            [7] = { label = 'Chief',           salary = 1000, isboss = true },
        },
    },

    -- ── Emergency Medical Services ───────────────────────────────────────────
    ['ambulance'] = {
        label  = 'Emergency Medical Services',
        type   = 'ems',
        grades = {
            [0] = { label = 'Trainee',        salary = 200 },
            [1] = { label = 'EMT',            salary = 350 },
            [2] = { label = 'Paramedic',      salary = 450 },
            [3] = { label = 'Senior Medic',   salary = 550 },
            [4] = { label = 'Supervisor',     salary = 650 },
            [5] = { label = 'Chief Medical',  salary = 800, isboss = true },
        },
    },

    -- ── Mechanic ─────────────────────────────────────────────────────────────
    ['mechanic'] = {
        label  = 'Mechanic',
        type   = 'mechanic',
        grades = {
            [0] = { label = 'Trainee',   salary = 150 },
            [1] = { label = 'Mechanic',  salary = 250 },
            [2] = { label = 'Senior',    salary = 350 },
            [3] = { label = 'Manager',   salary = 450, isboss = true },
        },
    },

    -- ── Real Estate ──────────────────────────────────────────────────────────
    ['realestate'] = {
        label  = 'Real Estate',
        grades = {
            [0] = { label = 'Agent',       salary = 200 },
            [1] = { label = 'Senior Agent',salary = 350 },
            [2] = { label = 'Broker',      salary = 500, isboss = true },
        },
    },

    -- ── Government ───────────────────────────────────────────────────────────
    ['government'] = {
        label  = 'Government',
        type   = 'government',
        grades = {
            [0] = { label = 'Employee',   salary = 200 },
            [1] = { label = 'Official',   salary = 400 },
            [2] = { label = 'Minister',   salary = 800, isboss = true },
        },
    },

    -- ── Taxi ─────────────────────────────────────────────────────────────────
    ['taxi'] = {
        label  = 'Taxi Company',
        grades = {
            [0] = { label = 'Driver',   salary = 150 },
            [1] = { label = 'Senior',   salary = 250 },
            [2] = { label = 'Manager',  salary = 400, isboss = true },
        },
    },
}

-- ─── Gang Definitions ────────────────────────────────────────────────────────
Galaxy.Config.Gangs = {

    ['none'] = {
        label  = 'No Gang',
        grades = {
            [0] = { label = 'none' },
        },
    },

    ['vagos'] = {
        label  = 'Vagos',
        grades = {
            [0] = { label = 'Recruit'  },
            [1] = { label = 'Soldier'  },
            [2] = { label = 'Enforcer' },
            [3] = { label = 'OG',       isboss = true },
        },
    },

    ['ballas'] = {
        label  = 'Ballas',
        grades = {
            [0] = { label = 'Recruit'  },
            [1] = { label = 'Soldier'  },
            [2] = { label = 'Enforcer' },
            [3] = { label = 'OG',       isboss = true },
        },
    },

    ['families'] = {
        label  = 'The Families',
        grades = {
            [0] = { label = 'Recruit'  },
            [1] = { label = 'Soldier'  },
            [2] = { label = 'Enforcer' },
            [3] = { label = 'OG',       isboss = true },
        },
    },
}
