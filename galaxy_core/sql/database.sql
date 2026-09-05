-- ═══════════════════════════════════════════════════════════════════════════════
-- GALAXY Core — Unified Database Schema (sql/database.sql)
-- ═══════════════════════════════════════════════════════════════════════════════
-- This schema is designed to satisfy column expectations from all three ecosystems:
--   • QBCore / QBX  →  citizenid, charinfo JSON, money JSON, metadata JSON
--   • ESX Legacy    →  identifier, accounts JSON (array), job, job_grade columns
--   • GALAXY Native →  all of the above in one coherent schema
--
-- Character data is split from player (account) data so multi-character works
-- cleanly and offline player lookups remain fast via indexed citizenid.
-- ═══════════════════════════════════════════════════════════════════════════════

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ─── Players (one row per real-world player) ──────────────────────────────────
CREATE TABLE IF NOT EXISTS `galaxy_players` (
    `id`          INT UNSIGNED     NOT NULL AUTO_INCREMENT,
    `license`     VARCHAR(60)      NOT NULL,                    -- "license:abc..."  (primary key for lookups)
    `license2`    VARCHAR(60)      DEFAULT NULL,                -- Rockstar license2 if present
    `steam`       VARCHAR(60)      DEFAULT NULL,
    `discord`     VARCHAR(60)      DEFAULT NULL,
    `fivem`       VARCHAR(60)      DEFAULT NULL,
    `name`        VARCHAR(100)     NOT NULL DEFAULT 'Unknown',
    `group`       VARCHAR(50)      NOT NULL DEFAULT 'user',     -- permission group (user/admin/superadmin)
    `banned`      TINYINT(1)       NOT NULL DEFAULT 0,
    `ban_reason`  TEXT             DEFAULT NULL,
    `ban_expire`  DATETIME         DEFAULT NULL,
    `lastSeen`    DATETIME         DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `firstSeen`   DATETIME         DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_license` (`license`),
    KEY `idx_steam`   (`steam`),
    KEY `idx_discord` (`discord`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── Characters (one row per character per player) ────────────────────────────
CREATE TABLE IF NOT EXISTS `galaxy_characters` (
    `id`          INT UNSIGNED     NOT NULL AUTO_INCREMENT,
    `license`     VARCHAR(60)      NOT NULL,                    -- FK to galaxy_players.license
    `slot`        TINYINT UNSIGNED NOT NULL DEFAULT 1,          -- character slot: 1, 2, 3
    `citizenid`   VARCHAR(25)      NOT NULL,                    -- "GAL-ABCDE-12345"  (QBCore-compatible)
    `deleted`     TINYINT(1)       NOT NULL DEFAULT 0,

    -- ── Character info (QBCore charinfo JSON / ESX name split) ──────────────
    -- ESX expects: firstname, lastname as separate columns OR inside JSON.
    -- We store as JSON but also expose a generated column for easy reads.
    `charinfo`    LONGTEXT         NOT NULL                     -- { firstname, lastname, dob, gender, nationality, phone, account }
                  CHECK (JSON_VALID(`charinfo`)),

    -- ── Money (QBCore: money JSON / ESX: accounts JSON array) ───────────────
    `money`       LONGTEXT         NOT NULL                     -- { cash, bank, black_money, crypto }
                  CHECK (JSON_VALID(`money`)),
    `accounts`    LONGTEXT         NOT NULL                     -- ESX array: [{ name, label, money }]
                  CHECK (JSON_VALID(`accounts`)),

    -- ── Job (ESX: separate columns / QBCore: job string + grade int) ─────────
    `job`         VARCHAR(50)      NOT NULL DEFAULT 'unemployed',
    `job_grade`   INT UNSIGNED     NOT NULL DEFAULT 0,
    `job2`        VARCHAR(50)      NOT NULL DEFAULT 'unemployed',  -- ESX secondary job
    `job2_grade`  INT UNSIGNED     NOT NULL DEFAULT 0,

    -- ── Gang (QBCore/QBX specific) ───────────────────────────────────────────
    `gang`        VARCHAR(50)      NOT NULL DEFAULT 'none',
    `gang_grade`  INT UNSIGNED     NOT NULL DEFAULT 0,

    -- ── Metadata (QBCore metadata JSON / ESX arbitrary storage) ─────────────
    `metadata`    LONGTEXT         NOT NULL                     -- { hunger, thirst, stress, isdead, licences, ... }
                  CHECK (JSON_VALID(`metadata`)),

    -- ── Position ─────────────────────────────────────────────────────────────
    `position`    LONGTEXT         NOT NULL                     -- { x, y, z, w }
                  CHECK (JSON_VALID(`position`)),

    `lastSeen`    DATETIME         DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_citizenid` (`citizenid`),
    KEY `idx_license`  (`license`),
    KEY `idx_job`      (`job`),
    KEY `idx_deleted`  (`deleted`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── ESX compatibility VIEW: `users` ─────────────────────────────────────────
-- Some very old ESX scripts do direct SQL on the `users` table.
-- This view maps the galaxy_characters schema to the expected ESX columns.
CREATE OR REPLACE VIEW `users` AS
SELECT
    c.`citizenid`                                          AS `identifier`,  -- ESX uses license as identifier, but citizenid is unique
    c.`license`                                            AS `license`,
    JSON_UNQUOTE(JSON_EXTRACT(c.`charinfo`, '$.firstname'))
        + ' ' +
    JSON_UNQUOTE(JSON_EXTRACT(c.`charinfo`, '$.lastname')) AS `name`,
    c.`accounts`                                           AS `accounts`,
    NULL                                                   AS `inventory`,   -- ESX legacy inventory not used
    NULL                                                   AS `loadout`,
    c.`job`                                                AS `job`,
    c.`job_grade`                                          AS `job_grade`,
    c.`metadata`                                           AS `status`,      -- ESX `status` column ≈ metadata
    c.`position`                                           AS `position`,
    p.`group`                                              AS `group`,
    p.`lastSeen`                                           AS `lastlogin`,
    p.`firstSeen`                                          AS `dateofbirth`,
    0                                                      AS `disabled`
FROM
    `galaxy_characters` c
JOIN
    `galaxy_players` p ON p.`license` = c.`license`
WHERE
    c.`deleted` = 0;

-- ─── Inventory (used when Config.InventorySystem == 'builtin') ────────────────
-- When ox_inventory is the backend, this table is unused but kept for portability.
CREATE TABLE IF NOT EXISTS `galaxy_inventory` (
    `id`          INT UNSIGNED     NOT NULL AUTO_INCREMENT,
    `citizenid`   VARCHAR(25)      NOT NULL,
    `slot`        SMALLINT UNSIGNED NOT NULL,
    `name`        VARCHAR(50)      NOT NULL,
    `count`       INT UNSIGNED     NOT NULL DEFAULT 1,
    `metadata`    LONGTEXT         DEFAULT '{}' CHECK (JSON_VALID(`metadata`)),
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_char_slot` (`citizenid`, `slot`),
    KEY `idx_citizenid` (`citizenid`),
    KEY `idx_name`      (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── Vehicles ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `galaxy_vehicles` (
    `id`          INT UNSIGNED     NOT NULL AUTO_INCREMENT,
    `citizenid`   VARCHAR(25)      NOT NULL,
    `plate`       VARCHAR(15)      NOT NULL,
    `model`       VARCHAR(60)      NOT NULL,
    `hash`        VARCHAR(15)      DEFAULT NULL,
    `mods`        LONGTEXT         DEFAULT '{}' CHECK (JSON_VALID(`mods`)),
    `fuel`        TINYINT UNSIGNED NOT NULL DEFAULT 100,
    `engine`      FLOAT            NOT NULL DEFAULT 1000.0,
    `body`        FLOAT            NOT NULL DEFAULT 1000.0,
    `garage`      VARCHAR(50)      DEFAULT NULL,
    `state`       TINYINT(1)       NOT NULL DEFAULT 0,          -- 0=garaged, 1=out
    `depotPrice`  INT UNSIGNED     NOT NULL DEFAULT 0,
    `drivingdistance` INT UNSIGNED NOT NULL DEFAULT 0,
    `fuelLevel`   TINYINT UNSIGNED NOT NULL DEFAULT 100,
    `balance`     INT UNSIGNED     NOT NULL DEFAULT 0,
    `paymentAmount` INT UNSIGNED   NOT NULL DEFAULT 0,
    `paymentsleft` INT UNSIGNED    NOT NULL DEFAULT 0,
    `financetime` INT UNSIGNED     NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_plate` (`plate`),
    KEY `idx_citizenid` (`citizenid`),
    KEY `idx_state`     (`state`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── Phone / Contacts (used by various phone resources) ────────────────────────
CREATE TABLE IF NOT EXISTS `galaxy_phone_contacts` (
    `id`          INT UNSIGNED     NOT NULL AUTO_INCREMENT,
    `citizenid`   VARCHAR(25)      NOT NULL,
    `number`      VARCHAR(20)      NOT NULL,
    `name`        VARCHAR(60)      NOT NULL,
    `iban`        VARCHAR(30)      DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── Phone / Messages ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `galaxy_phone_messages` (
    `id`          INT UNSIGNED     NOT NULL AUTO_INCREMENT,
    `citizenid`   VARCHAR(25)      NOT NULL,
    `sender`      VARCHAR(20)      NOT NULL,
    `message`     TEXT             NOT NULL,
    `isRead`      TINYINT(1)       NOT NULL DEFAULT 0,
    `createdAt`   DATETIME         DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── Apartments / Housing ─────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `galaxy_apartments` (
    `id`          INT UNSIGNED     NOT NULL AUTO_INCREMENT,
    `citizenid`   VARCHAR(25)      NOT NULL,
    `name`        VARCHAR(60)      NOT NULL,
    `label`       VARCHAR(60)      NOT NULL DEFAULT '',
    `type`        VARCHAR(20)      NOT NULL DEFAULT 'apartment',
    `furniture`   LONGTEXT         DEFAULT '{}' CHECK (JSON_VALID(`furniture`)),
    `owned`       TINYINT(1)       NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    KEY `idx_citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── Stash / Storage ──────────────────────────────────────────────────────────
-- Used by ox_inventory or custom stash resources
CREATE TABLE IF NOT EXISTS `ox_inventory` (
    `owner`       VARCHAR(60)      NOT NULL DEFAULT '',
    `name`        VARCHAR(60)      NOT NULL,
    `data`        LONGTEXT         NOT NULL CHECK (JSON_VALID(`data`)),
    PRIMARY KEY (`owner`, `name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── Licenses ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `galaxy_licenses` (
    `id`          INT UNSIGNED     NOT NULL AUTO_INCREMENT,
    `citizenid`   VARCHAR(25)      NOT NULL,
    `type`        VARCHAR(30)      NOT NULL,                    -- 'driver', 'weapon', 'hunting', 'business'
    `acquired`    DATETIME         DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_cid_type` (`citizenid`, `type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── Businesses / Societies (ESX society compat) ──────────────────────────────
CREATE TABLE IF NOT EXISTS `galaxy_societies` (
    `id`          INT UNSIGNED     NOT NULL AUTO_INCREMENT,
    `name`        VARCHAR(60)      NOT NULL,
    `label`       VARCHAR(100)     NOT NULL DEFAULT '',
    `money`       INT UNSIGNED     NOT NULL DEFAULT 0,
    `type`        VARCHAR(20)      NOT NULL DEFAULT 'private',
    `boss_grade`  INT UNSIGNED     NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── Ban System ───────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `galaxy_bans` (
    `id`          INT UNSIGNED     NOT NULL AUTO_INCREMENT,
    `license`     VARCHAR(60)      NOT NULL,
    `name`        VARCHAR(100)     NOT NULL DEFAULT 'Unknown',
    `reason`      TEXT             DEFAULT NULL,
    `expire`      DATETIME         DEFAULT NULL,                -- NULL = permanent
    `bannedBy`    VARCHAR(100)     NOT NULL DEFAULT 'Server',
    `bannedAt`    DATETIME         DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_license` (`license`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET FOREIGN_KEY_CHECKS = 1;

-- ═══════════════════════════════════════════════════════════════════════════════
-- Default data
-- ═══════════════════════════════════════════════════════════════════════════════

-- Default societies / job accounts (ESX society scripts expect these rows)
INSERT IGNORE INTO `galaxy_societies` (`name`, `label`, `money`, `type`, `boss_grade`) VALUES
    ('police',     'Police Department',  50000, 'public',  7),
    ('ambulance',  'EMS / Hospital',     25000, 'public',  5),
    ('mechanic',   'Mechanic Shop',      10000, 'private', 3),
    ('taxi',       'Taxi Company',        5000, 'private', 2);

-- ═══════════════════════════════════════════════════════════════════════════════
-- NOTE: ox_inventory manages its own table (`ox_inventory` above).
-- If you switch to oxmysql-based storage, it will create/migrate its own tables.
-- The `ox_inventory` stub above ensures no resource fails on startup.
-- ═══════════════════════════════════════════════════════════════════════════════
