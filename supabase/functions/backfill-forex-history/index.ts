import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface HistoricalPrice {
    asset_code: string
    date: string
    open: number
    high: number
    low: number
    close: number
    volume: number | null
    category: string
    provider: string
}

Deno.serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
        const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        const supabase = createClient(supabaseUrl, supabaseKey)

        // Get parameters from request
        const { days = 365 } = await req.json().catch(() => ({}))

        const endDate = new Date()
        endDate.setHours(0, 0, 0, 0)

        // Calculate start date by subtracting milliseconds
        const startDate = new Date(endDate.getTime() - (days * 24 * 60 * 60 * 1000))

        // Fetch forex assets
        const { data: assets, error: assetsError } = await supabase
            .from('assets')
            .select('code, display_name')
            .eq('category', 'forex')

        if (assetsError) throw assetsError
        if (!assets || assets.length === 0) {
            return new Response(JSON.stringify({ message: 'No forex assets found' }), {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 200,
            })
        }

        // Frankfurter only supports EUR as base currency
        // We need to fetch all currencies and calculate cross rates
        const allCurrencies = new Set<string>()

        for (const asset of assets) {
            const [base, quote] = asset.code.split('/')
            allCurrencies.add(base)
            allCurrencies.add(quote)
        }

        // Remove EUR as it's the base
        allCurrencies.delete('EUR')
        const currenciesStr = Array.from(allCurrencies).join(',')

        const historicalPrices: HistoricalPrice[] = []

        // Frankfurter has a 90-day limit per request
        // Split into 90-day chunks
        const chunkDays = 90
        let currentStart = new Date(startDate)

        while (currentStart < endDate) {
            const currentEnd = new Date(currentStart)
            currentEnd.setDate(currentEnd.getDate() + chunkDays)

            if (currentEnd > endDate) {
                currentEnd.setTime(endDate.getTime())
            }

            // Fetch historical data from Frankfurter (EUR base)
            const url = `https://api.frankfurter.app/${formatDate(currentStart)}..${formatDate(currentEnd)}?from=EUR&to=${currenciesStr}`

            console.log(`Fetching ${formatDate(currentStart)} to ${formatDate(currentEnd)}`)
            const response = await fetch(url)

            if (!response.ok) {
                console.error(`Frankfurter API error: ${response.statusText}`)
                // Continue to next chunk
                currentStart = new Date(currentEnd)
                currentStart.setDate(currentStart.getDate() + 1)
                continue
            }

            const data = await response.json()

            if (!data.rates) {
                console.error('No rates in response')
                currentStart = new Date(currentEnd)
                currentStart.setDate(currentStart.getDate() + 1)
                continue
            }

            console.log(`Received ${Object.keys(data.rates).length} days`)

            // Process each date
            for (const [date, eurRates] of Object.entries(data.rates)) {
                // eurRates = { USD: 1.08, TRY: 32.5, GBP: 0.85, ... }
                const rates = eurRates as Record<string, number>

                // Add EUR itself
                const allRates: Record<string, number> = { EUR: 1.0, ...rates }

                // Calculate cross rates for each asset
                for (const asset of assets) {
                    const [base, quote] = asset.code.split('/')

                    const baseRate = allRates[base]
                    const quoteRate = allRates[quote]

                    if (baseRate && quoteRate) {
                        // Cross rate: base/quote = (EUR/quote) / (EUR/base)
                        const crossRate = quoteRate / baseRate

                        historicalPrices.push({
                            asset_code: asset.code,
                            date: date,
                            open: crossRate,
                            high: crossRate,
                            low: crossRate,
                            close: crossRate,
                            volume: null,
                            category: 'forex',
                            provider: 'frankfurter',
                        })
                    }
                }
            }

            // Move to next chunk
            currentStart = new Date(currentEnd)
            currentStart.setDate(currentStart.getDate() + 1)
        }

        console.log(`Generated ${historicalPrices.length} historical price records`)

        // Insert in batches to avoid timeout
        const batchSize = 1000
        let inserted = 0

        for (let i = 0; i < historicalPrices.length; i += batchSize) {
            const batch = historicalPrices.slice(i, i + batchSize)

            const { error: insertError } = await supabase
                .from('historical_prices')
                .upsert(batch, { onConflict: 'asset_code,date' })

            if (insertError) {
                console.error('Insert error:', insertError)
                throw insertError
            }

            inserted += batch.length
            console.log(`Inserted ${inserted}/${historicalPrices.length}`)
        }

        return new Response(
            JSON.stringify({
                success: true,
                assets: assets.length,
                days: days,
                total_records: historicalPrices.length,
                inserted: inserted,
                date_range: {
                    start: formatDate(startDate),
                    end: formatDate(endDate),
                },
            }),
            {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 200,
            }
        )

    } catch (error: any) {
        console.error('Error:', error)
        return new Response(
            JSON.stringify({ success: false, error: error.message }),
            {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 500,
            }
        )
    }
})

function formatDate(date: Date): string {
    return date.toISOString().split('T')[0]
}
