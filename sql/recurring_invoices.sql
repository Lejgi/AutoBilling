CREATE TABLE IF NOT EXISTS `recurring_invoices` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `label` VARCHAR(255) NOT NULL,
    `identifier` VARCHAR(60) NOT NULL,
    `amount` INT NOT NULL,
    `period_days` INT NOT NULL,
    `next_due` BIGINT NOT NULL,
    `sender_job` VARCHAR(60) DEFAULT NULL,
    `auto_increase` INT NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    INDEX `identifier_idx` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
