# Recurring Billing pro okokBilling s ox_target

Tento resource přidává jednoduchý systém měsíčních faktur napojený na [`okokBilling`](https://okok.tebex.io/).
Správci mohou přes stolní interakci z `ox_target` otevřít formulář z `ox_lib`, vyplnit identifier hráče ve tvaru `charX:Y`
a částku, a skript následně každý měsíc automaticky vytvoří fakturu přes okokBilling.

## Funkce

- Stolní interakce přes `ox_target`, která otevře `ox_lib` dialog pro zadání nové měsíční platby.
- Ukládání periodických faktur do tabulky `recurring_invoices` (oxmysql nebo mysql-async).
- Automatické odeslání faktury jednou za měsíc s logem do konzole a volitelně na Discord webhook.
- Volitelná kontrola jobu hráče (např. realestate), který může stolík používat.

## Instalace

1. Naimportuj SQL soubor [`sql/recurring_invoices.sql`](sql/recurring_invoices.sql) do databáze.
2. Ujisti se, že máš nainstalované a spuštěné resources `ox_lib`, `ox_target`, `okokBilling` a databázový resource (`oxmysql` nebo `mysql-async`).
3. Zkopíruj složku resource do `resources` a přidej do `server.cfg` např. `ensure recurring_billing`.
4. Uprav [`config.lua`](config.lua):
   - `MonthlyPeriodDays` – délka cyklu v dnech (výchozí 30).
   - `CheckInterval` – jak často (v sekundách) se kontroluje tabulka a posílají faktury.
   - `DefaultSenderJob` / `DefaultInvoiceLabel` – výchozí hodnoty pro vytvářené faktury.
   - `AllowedJobs` – seznam jobů, které mohou stolík používat (ponech prázdné pro povolení všem).
   - `RecurringTables` – seznam stolů / zón, kde se má objevit target interakce (můžeš přidat víc souřadnic, velikost, label…).
   - `WebhookURL` – volitelný Discord webhook pro logování automatických faktur.

## Použití

1. Přijdi k definovanému stolu a stiskni interakci `ox_target`.
2. Vyplň identifier hráče ve tvaru `charX:Y` (např. `char1:42`), částku v Kč/$ a případně vlastní label faktury.
3. Po potvrzení se položka uloží a skript začne fakturovat každý měsíc.

> Faktury se vytváří stejným způsobem, jako kdyby byly ručně vytvořeny v UI okokBilling.

## SQL schéma

```sql
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
```
