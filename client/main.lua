local Config = Config

local targetIds = {}

local function notifyError(message)
    lib.notify({
        title = 'Termínové platby',
        description = message,
        type = 'error'
    })
end

local function openRecurringDialog()
    local defaultLabel = Config.DefaultInvoiceLabel or 'Měsíční platba'

    local input = lib.inputDialog('Nová termínová platba', {
        {
            type = 'input',
            label = 'Identifier hráče',
            description = 'Zadej identifier ve tvaru char1:1',
            placeholder = 'char1:1',
            required = true
        },
        {
            type = 'number',
            label = 'Částka',
            description = 'Kolik se má hráči fakturovat každý měsíc',
            required = true,
            min = 1,
            step = 1
        },
        {
            type = 'input',
            label = 'Label faktury',
            placeholder = defaultLabel,
            default = defaultLabel
        }
    })

    if not input then
        return
    end

    local identifier = input[1] and input[1]:lower() or ''
    if not identifier:match('^char%d+:%d+$') then
        notifyError('Identifier musí být ve tvaru charX:Y (např. char1:1).')
        return
    end

    local amount = tonumber(input[2]) or 0
    if amount <= 0 then
        notifyError('Částka musí být větší než 0.')
        return
    end

    local label = input[3]
    if not label or label == '' then
        label = defaultLabel
    end

    TriggerServerEvent('recurring_billing:createRecurringInvoice', {
        identifier = identifier,
        amount = math.floor(amount + 0.5),
        label = label
    })
end

local function addTargetZones()
    if not Config.RecurringTables then
        return
    end

    for index, data in ipairs(Config.RecurringTables) do
        local coords = data.coords
        if type(coords) == 'table' then
            coords = vec3(coords.x or coords[1], coords.y or coords[2], coords.z or coords[3])
        end

        local size = data.size or vec3(1.4, 1.4, 1.2)
        if type(size) == 'table' then
            size = vec3(size.x or size[1], size.y or size[2], size.z or size[3])
        end

        local zoneId = exports.ox_target:addBoxZone({
            coords = coords,
            size = size,
            rotation = data.rotation or 0.0,
            debug = data.debug or false,
            options = {
                {
                    name = string.format('recurring_billing:%s', index),
                    icon = data.icon or 'fa-solid fa-file-invoice-dollar',
                    label = data.label or 'Termínové platby',
                    onSelect = openRecurringDialog
                }
            }
        })

        if zoneId then
            targetIds[#targetIds + 1] = zoneId
        end
    end
end

local function removeTargetZones()
    for _, id in ipairs(targetIds) do
        exports.ox_target:removeZone(id)
    end
    targetIds = {}
end

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then
        return
    end
    addTargetZones()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then
        return
    end
    removeTargetZones()
end)

if GetResourceState('ox_target') == 'started' then
    addTargetZones()
else
    CreateThread(function()
        while GetResourceState('ox_target') ~= 'started' do
            Wait(500)
        end
        addTargetZones()
    end)
end

RegisterNetEvent('recurring_billing:notify', function(data)
    if type(data) ~= 'table' then
        return
    end

    lib.notify({
        title = data.title or 'Termínové platby',
        description = data.description or '',
        type = data.type or 'inform'
    })
end)
