Config = {}

-- Kolik dní má mít jeden fakturační cyklus (výchozí 30 dní = měsíčně)
Config.MonthlyPeriodDays = 30

-- Jak často (v sekundách) se kontroluje, zda mají být odeslány nové faktury
Config.CheckInterval = 60 * 60 -- každou hodinu

-- Výchozí odesílatel faktury, pokud není uveden jiný (např. job nebo společnost)
Config.DefaultSenderJob = 'reality'

-- Výchozí label faktury, pokud jej hráč nevyplní v dialogu
Config.DefaultInvoiceLabel = 'Měsíční platba'

-- Discord webhook URL pro logování (ponech prázdné pro vypnutí)
Config.WebhookURL = ''

-- Seznam jobů, které mohou vytvářet termínové platby. Ponech prázdné {} pro povolení všem.
Config.AllowedJobs = {
    reality = true
}

-- Definice "stolů" / míst, na kterých se zobrazí ox_target interakce
Config.RecurringTables = {
    {
        coords = vec3(299.7845, 183.4109, 104.1377),
        size = vec3(1.2, 1.2, 1.0),
        rotation = 250.0,
        label = 'Správa termínových plateb',
        icon = 'fa-solid fa-file-invoice-dollar'
    }
}

return Config
