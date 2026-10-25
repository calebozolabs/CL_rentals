--[[ ═══════════════════════════════════════════════════════════════════════
     DATABASE
     Tables are created on start (install/install.sql has the same SQL).
       cl_rentals_locations   desks built in /rentaladmin (one JSON row each)
       cl_rentals_history     every rental, active or finished
       cl_rentals_settings    in-game settings edits
     ═══════════════════════════════════════════════════════════════════════ ]]

DB = {}

local SCHEMA = {
    [[CREATE TABLE IF NOT EXISTS `cl_rentals_locations` (
        `id` VARCHAR(64) NOT NULL,
        `data` LONGTEXT NOT NULL,
        `sort` INT NOT NULL DEFAULT 0,
        `updated_at` INT NOT NULL DEFAULT 0,
        PRIMARY KEY (`id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `cl_rentals_history` (
        `id` INT NOT NULL AUTO_INCREMENT,
        `identifier` VARCHAR(64) NOT NULL,
        `name` VARCHAR(100) NOT NULL DEFAULT '',
        `location` VARCHAR(64) NOT NULL DEFAULT '',
        `location_label` VARCHAR(64) NOT NULL DEFAULT '',
        `model` VARCHAR(64) NOT NULL,
        `label` VARCHAR(64) NOT NULL DEFAULT '',
        `category` VARCHAR(64) NOT NULL DEFAULT '',
        `plate` VARCHAR(8) NOT NULL DEFAULT '',
        `duration_id` VARCHAR(16) NOT NULL DEFAULT '',
        `minutes` INT NOT NULL DEFAULT 0,
        `price` INT NOT NULL DEFAULT 0,
        `deposit` INT NOT NULL DEFAULT 0,
        `account` VARCHAR(16) NOT NULL DEFAULT 'bank',
        `paid` INT NOT NULL DEFAULT 0,
        `recharges` INT NOT NULL DEFAULT 0,
        `refund` INT NOT NULL DEFAULT 0,
        `refund_due` INT NOT NULL DEFAULT 0,
        `damage` INT NOT NULL DEFAULT 0,
        `status` VARCHAR(16) NOT NULL DEFAULT 'active',
        `started_at` INT NOT NULL DEFAULT 0,
        `expires_at` INT NOT NULL DEFAULT 0,
        `ended_at` INT NOT NULL DEFAULT 0,
        PRIMARY KEY (`id`),
        KEY `identifier` (`identifier`),
        KEY `status` (`status`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `cl_rentals_settings` (
        `key` VARCHAR(64) NOT NULL,
        `value` LONGTEXT NOT NULL,
        `updated_by` VARCHAR(100) NOT NULL DEFAULT '',
        `updated_at` INT NOT NULL DEFAULT 0,
        PRIMARY KEY (`key`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
}

function DB.Init()
    for _, sql in ipairs(SCHEMA) do MySQL.query.await(sql) end
end

function DB.decode(raw, fallback)
    if type(raw) ~= 'string' or raw == '' then return fallback end
    local ok, value = pcall(json.decode, raw)
    if ok and value ~= nil then return value end
    return fallback
end

--[[ ─── Locations ──────────────────────────────────────────────────────── ]]

function DB.Locations()
    return MySQL.query.await('SELECT `id`, `data` FROM `cl_rentals_locations` ORDER BY `sort`, `id`') or {}
end

function DB.SaveLocation(loc, sort)
    MySQL.query.await('INSERT INTO `cl_rentals_locations` (`id`, `data`, `sort`, `updated_at`) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE `data` = VALUES(`data`), `updated_at` = VALUES(`updated_at`)',
        { loc.id, json.encode(loc), sort or 0, os.time() })
end

function DB.DeleteLocation(id)
    MySQL.query.await('DELETE FROM `cl_rentals_locations` WHERE `id` = ?', { id })
end

--[[ ─── Rentals ────────────────────────────────────────────────────────── ]]

function DB.CreateRental(r)
    return MySQL.insert.await([[INSERT INTO `cl_rentals_history`
        (`identifier`, `name`, `location`, `location_label`, `model`, `label`, `category`, `plate`, `duration_id`, `minutes`, `price`, `deposit`, `account`, `paid`, `status`, `started_at`, `expires_at`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'active', ?, ?)]],
        { r.cid, r.name, r.location, r.locationLabel, r.model, r.label, r.categoryLabel, r.plate, r.durationId, r.minutes, r.price, r.deposit, r.account, r.paid, r.startedAt, r.expiresAt })
end

function DB.UpdateRental(r)
    MySQL.update.await('UPDATE `cl_rentals_history` SET `plate` = ?, `paid` = ?, `recharges` = ?, `expires_at` = ?, `status` = ?, `refund` = ?, `damage` = ?, `ended_at` = ? WHERE `id` = ?',
        { r.plate, r.paid, r.recharges, r.expiresAt, r.status, r.refund or 0, r.damage or 0, r.endedAt or 0, r.id })
end

function DB.Rental(id)
    return MySQL.single.await('SELECT * FROM `cl_rentals_history` WHERE `id` = ?', { id })
end

function DB.LatestRental(identifier)
    return MySQL.single.await('SELECT * FROM `cl_rentals_history` WHERE `identifier` = ? ORDER BY `id` DESC LIMIT 1', { identifier })
end

function DB.PlayerHistory(identifier, limit)
    return MySQL.query.await('SELECT * FROM `cl_rentals_history` WHERE `identifier` = ? AND `status` NOT IN (\'active\', \'overdue\') ORDER BY `id` DESC LIMIT ?', { identifier, limit or 10 }) or {}
end

function DB.History(limit)
    return MySQL.query.await('SELECT * FROM `cl_rentals_history` ORDER BY `id` DESC LIMIT ?', { limit or 60 }) or {}
end

function DB.Stats()
    local since = os.time() - 86400
    return MySQL.single.await([[SELECT COUNT(*) AS `total`, COALESCE(SUM(`paid`), 0) AS `revenue`,
        COALESCE(SUM(CASE WHEN `started_at` >= ? THEN 1 ELSE 0 END), 0) AS `today`,
        COALESCE(SUM(CASE WHEN `started_at` >= ? THEN `paid` ELSE 0 END), 0) AS `todayRevenue`,
        COALESCE(SUM(CASE WHEN `status` = 'repossessed' THEN 1 ELSE 0 END), 0) AS `repossessed`
        FROM `cl_rentals_history`]], { since, since }) or {}
end

--- Rentals still open from before this start: their vehicles are gone.
function DB.CloseOrphans(refund)
    local rows = MySQL.query.await("SELECT `id`, `deposit` FROM `cl_rentals_history` WHERE `status` IN ('active', 'overdue')") or {}
    for _, row in ipairs(rows) do
        MySQL.update.await("UPDATE `cl_rentals_history` SET `status` = 'restart', `ended_at` = ?, `refund_due` = ? WHERE `id` = ?",
            { os.time(), refund and row.deposit or 0, row.id })
    end
    return #rows
end

function DB.RefundsDue(identifier)
    return MySQL.query.await('SELECT `id`, `refund_due`, `account`, `label`, `plate` FROM `cl_rentals_history` WHERE `identifier` = ? AND `refund_due` > 0', { identifier }) or {}
end

function DB.RefundPaid(id, amount)
    MySQL.update.await('UPDATE `cl_rentals_history` SET `refund_due` = 0, `refund` = ? WHERE `id` = ?', { amount, id })
end

--[[ ─── Settings ───────────────────────────────────────────────────────── ]]

function DB.Settings()
    return MySQL.query.await('SELECT `key`, `value` FROM `cl_rentals_settings`') or {}
end

function DB.SaveSetting(key, value, by)
    MySQL.query.await('INSERT INTO `cl_rentals_settings` (`key`, `value`, `updated_by`, `updated_at`) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE `value` = VALUES(`value`), `updated_by` = VALUES(`updated_by`), `updated_at` = VALUES(`updated_at`)',
        { key, json.encode({ v = value }), by or '', os.time() })
end

function DB.DeleteSetting(key)
    MySQL.query.await('DELETE FROM `cl_rentals_settings` WHERE `key` = ?', { key })
end
