-- CL Rentals creates these tables by itself on start.
-- Only run this file if your database user may not create tables.

CREATE TABLE IF NOT EXISTS `cl_rentals_locations` (
    `id` VARCHAR(64) NOT NULL,
    `data` LONGTEXT NOT NULL,
    `sort` INT NOT NULL DEFAULT 0,
    `updated_at` INT NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `cl_rentals_history` (
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `cl_rentals_settings` (
    `key` VARCHAR(64) NOT NULL,
    `value` LONGTEXT NOT NULL,
    `updated_by` VARCHAR(100) NOT NULL DEFAULT '',
    `updated_at` INT NOT NULL DEFAULT 0,
    PRIMARY KEY (`key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ESX only: the contract item (skip if you use ox_inventory, see README_ITEMS.md)
-- INSERT IGNORE INTO `items` (`name`, `label`, `weight`) VALUES ('rental_contract', 'Rental Contract', 1);
