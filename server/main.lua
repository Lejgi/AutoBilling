local Config = Config or {}

local ESX

local function fetchESX()
    if ESX then
        return ESX
    end

    if exports and exports['es_extended'] then
        local ok, sharedObject = pcall(exports['es_extended'].getSharedObject, exports['es_extended'])
        if ok and sharedObject then
            ESX = sharedObject
            return ESX
        end
    end

    local legacyObject
    TriggerEvent('esx:getSharedObject', function(obj)
        legacyObject = obj
    end)

    if legacyObject then
        ESX = legacyObject
        return ESX
    end

    return nil
end

fetchESX()

local DAY_SECONDS = 86400
local MONTH_PERIOD = math.max(1, Config.MonthlyPeriodDays or 30)

local function ensureDependencies()
    if GetResourceState('okokBilling') ~= 'started' then
        print('^1[RecurringBilling]^0 okokBilling resource is not started. Recurring faktury nebudou odesílány.')
        return false
    end
    return true
end

local function getDatabaseDriver()
    if GetResourceState('oxmysql') == 'started' then
        return 'oxmysql'
    elseif type(MySQL) == 'table' and MySQL.Sync and MySQL.Async then
        return 'mysql-async'
    end

    print('^1[RecurringBilling]^0 Nebyl nalezen podporovaný databázový resource (oxmysql nebo mysql-async)!')
    return nil
end

local dbDriver = getDatabaseDriver()

local function trim(value)
    if type(value) ~= 'string' then
        return value
    end
    return value:match('^%s*(.-)%s*$')
end

local function dbFetch(query, params)
    if dbDriver == 'oxmysql' then
        return exports.oxmysql:fetchSync(query, params)
    elseif dbDriver == 'mysql-async' then
        return MySQL.Sync.fetchAll(query, params)
    end
    return {}
end

local function dbExecute(query, params)
    if dbDriver == 'oxmysql' then
        return exports.oxmysql:executeSync(query, params)
    elseif dbDriver == 'mysql-async' then
        return MySQL.Sync.execute(query, params)
    end
end

local function dbInsert(query, params)
    if dbDriver == 'oxmysql' then
        return exports.oxmysql:insertSync(query, params)
    elseif dbDriver == 'mysql-async' then
        return MySQL.Sync.insert(query, params)
    end
end

local function notifyPlayer(src, data)
    TriggerClientEvent('recurring_billing:notify', src, data)
end

local function isJobAllowed(src)
    if type(Config.AllowedJobs) ~= 'table' or next(Config.AllowedJobs) == nil then
        return true
    end

    local esxObject = ESX or fetchESX()

    if not esxObject or type(esxObject.GetPlayerFromId) ~= 'function' then
        print('^3[RecurringBilling]^0 Upozornění: Konfigurace vyžaduje ověření jobu, ale ESX nebyl nalezen. Povoluji všem pro jistotu.')
        return true
    end

    local xPlayer = esxObject.GetPlayerFromId(src)
    if not xPlayer or not xPlayer.job then
        return false
    end

    return Config.AllowedJobs[xPlayer.job.name] == true
end

local function resolveSender(invoice)
    if invoice.sender_job and invoice.sender_job ~= '' then
        return invoice.sender_job
    end
    return Config.DefaultSenderJob or 'council'
end

local function logInvoice(data)
    local message = string.format('[RecurringBilling] Faktura pro identifier %s byla odeslána – částka %s$, label: %s', data.identifier, data.amount, data.label)
    print(message)

    if Config.WebhookURL and Config.WebhookURL ~= '' then
        PerformHttpRequest(Config.WebhookURL, function() end, 'POST', json.encode({
            username = 'Recurring Billing',
            embeds = {
                {
                    title = 'Automatická faktura odeslána',
                    description = string.format('Label: **%s**\nIdentifier: `%s`\nČástka: **%s$**\nOdesílatel: %s', data.label, data.identifier, data.amount, data.sender),
                    color = 3447003,
                    footer = { text = os.date('%Y-%m-%d %H:%M:%S', os.time()) }
                }
            }
        }), { ['Content-Type'] = 'application/json' })
    end
end

local function sendInvoice(invoice)
    if not ensureDependencies() then
        return false
    end

    local sender = resolveSender(invoice)
    local success, err = pcall(function()
        exports['okokBilling']:CreateInvoice(invoice.label, sender, invoice.identifier, invoice.amount, false)
    end)

    if not success then
        print(('^1[RecurringBilling]^0 Nepodařilo se vytvořit fakturu pro %s (%s): %s'):format(invoice.label, invoice.identifier, err or 'Neznámá chyba'))
        return false
    end

    logInvoice({
        label = invoice.label,
        identifier = invoice.identifier,
        amount = invoice.amount,
        sender = sender
    })

    return true
end

local function processInvoice(invoice)
    local now = os.time()
    local periodSeconds = (invoice.period_days or MONTH_PERIOD) * DAY_SECONDS

    while invoice.next_due <= now do
        if sendInvoice(invoice) then
            invoice.next_due = invoice.next_due + periodSeconds
            dbExecute('UPDATE recurring_invoices SET next_due = ? WHERE id = ?', { invoice.next_due, invoice.id })
            now = os.time()
        else
            break
        end
    end
end

local function checkInvoices()
    if not dbDriver then
        dbDriver = getDatabaseDriver()
        if not dbDriver then
            return
        end
    end

    local now = os.time()
    local invoices = dbFetch('SELECT * FROM recurring_invoices WHERE next_due <= ?', { now })

    for _, invoice in ipairs(invoices) do
        processInvoice(invoice)
    end
end

CreateThread(function()
    Wait(5000)
    checkInvoices()

    local interval = math.max(60, (Config.CheckInterval or (12 * 60 * 60)))

    while true do
        Wait(interval * 1000)
        checkInvoices()
    end
end)

RegisterNetEvent('recurring_billing:createRecurringInvoice', function(payload)
    local src = source
    if src == 0 then
        return
    end

    if not dbDriver then
        dbDriver = getDatabaseDriver()
        if not dbDriver then
            notifyPlayer(src, {
                title = 'Termínové platby',
                description = 'Databáze není dostupná. Zkuste to prosím později.',
                type = 'error'
            })
            return
        end
    end

    if type(payload) ~= 'table' then
        return
    end

    if not isJobAllowed(src) then
        notifyPlayer(src, {
            title = 'Termínové platby',
            description = 'Nemáš oprávnění používat tento stůl.',
            type = 'error'
        })
        return
    end

    local identifierInput = payload.identifier
    if identifierInput == nil then
        notifyPlayer(src, {
            title = 'Termínové platby',
            description = 'Musíš zadat serverové ID nebo identifier hráče.',
            type = 'error'
        })
        return
    end

    if type(identifierInput) ~= 'string' then
        identifierInput = tostring(identifierInput)
    end

    identifierInput = trim(identifierInput or '') or ''
    if identifierInput == '' then
        notifyPlayer(src, {
            title = 'Termínové platby',
            description = 'Musíš zadat serverové ID nebo identifier hráče.',
            type = 'error'
        })
        return
    end

    local identifier = identifierInput:lower()

    if identifier:match('^%d+$') then
        local esxObject = ESX or fetchESX()

        if not esxObject or type(esxObject.GetPlayerFromId) ~= 'function' then
            notifyPlayer(src, {
                title = 'Termínové platby',
                description = 'Serverové ID lze použít pouze pokud je dostupný ESX. Zadej prosím identifier ve tvaru charX:Y.',
                type = 'error'
            })
            return
        end

        local targetSource = tonumber(identifier)
        local xPlayer = targetSource and esxObject.GetPlayerFromId(targetSource) or nil
        if not xPlayer then
            notifyPlayer(src, {
                title = 'Termínové platby',
                description = ('Hráč s ID %s není online. Pokud je offline, zadej jeho identifier ve tvaru charX:Y ručně.'):format(identifierInput),
                type = 'error'
            })
            return
        end

        local resolvedIdentifier
        if type(xPlayer.getIdentifier) == 'function' then
            local ok, value = pcall(xPlayer.getIdentifier, xPlayer)
            if ok then
                resolvedIdentifier = value
            end
        end

        if not resolvedIdentifier and type(xPlayer.identifier) == 'string' then
            resolvedIdentifier = xPlayer.identifier
        end

        if type(resolvedIdentifier) == 'string' then
            resolvedIdentifier = resolvedIdentifier:lower()
        end

        if not resolvedIdentifier or not resolvedIdentifier:match('^char%d+:%d+$') then
            notifyPlayer(src, {
                title = 'Termínové platby',
                description = ('Nepodařilo se získat platný identifier pro hráče %s. Zadej prosím identifier ve tvaru charX:Y ručně.'):format(identifierInput),
                type = 'error'
            })
            return
        end

        identifier = resolvedIdentifier
    end

    if not identifier:match('^char%d+:%d+$') then
        notifyPlayer(src, {
            title = 'Termínové platby',
            description = 'Identifier musí být ve tvaru charX:Y (např. char1:1). Pokud hráč není online, zadej jeho identifier ručně.',
            type = 'error'
        })
        return
    end

    local amount = tonumber(payload.amount)
    if not amount or amount <= 0 then
        notifyPlayer(src, {
            title = 'Termínové platby',
            description = 'Částka musí být kladné číslo.',
            type = 'error'
        })
        return
    end

    amount = math.floor(amount + 0.5)
    local label = (type(payload.label) == 'string' and payload.label ~= '') and payload.label or (Config.DefaultInvoiceLabel or 'Měsíční platba')
    local senderJob = Config.DefaultSenderJob or ''

    local now = os.time()
    local nextDue = now + (MONTH_PERIOD * DAY_SECONDS)

    local insertedId = dbInsert('INSERT INTO recurring_invoices (label, identifier, amount, period_days, next_due, sender_job, auto_increase) VALUES (?, ?, ?, ?, ?, ?, 0)', {
        label,
        identifier,
        amount,
        MONTH_PERIOD,
        nextDue,
        senderJob
    })

    if not insertedId then
        notifyPlayer(src, {
            title = 'Termínové platby',
            description = 'Nepodařilo se uložit fakturu. Zkontroluj konzoli serveru.',
            type = 'error'
        })
        return
    end

    notifyPlayer(src, {
        title = 'Termínové platby',
        description = ('Měsíční faktura pro %s byla úspěšně nastavena.'):format(identifier),
        type = 'success'
    })

    print(('^2[RecurringBilling]^0 %s vytvořil(a) novou měsíční fakturu pro %s (%s$).'):format(GetPlayerName(src) or ('ID ' .. src), identifier, amount))
end)
