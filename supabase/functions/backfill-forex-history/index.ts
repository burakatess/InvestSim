import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface HistoricalPrice {
    asset_id: string
    date: string
    open: number
    high: number
    low: number
    close: number
    volume: number | null
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

        // Calculate start date
        const startDate = new Date(endDate.getTime() - (days * 24 * 60 * 60 * 1000))

        // Fetch forex assets (using correct schema)
        const { data: assets, error: assetsError } = await supabase
            .from('assets')
            .select('id, symbol, display_name')
            .eq('asset_class', 'fx')

        if (assetsError) throw assetsError
        if (!assets || assets.length === 0) {
            return new Response(JSON.stringify({ message: 'No forex assets found' }), {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 200,
            })
        }

        console.log(`Found ${assets.length} forex assets`)

        // Collect all currencies needed
        const allCurrencies = new Set<string>()
        for (const asset of assets) {
            const symbol = asset.symbol.replace(/[\/-]/g, '').toUpperCase()
            if (symbol.length === 6) {
                allCurrencies.add(symbol.substring(0, 3))
                allCurrencies.add(symbol.substring(3, 6))
            }
        }

        // Remove EUR as it's the base
        allCurrencies.delete('EUR')
        const currenciesStr = Array.from(allCurrencies).join(',')

        console.log(`Currencies needed: ${currenciesStr}`)

        // Use Map for deduplication (key = asset_id + date)
        const priceMap = new Map<string, HistoricalPrice>()

        // Frankfurter has a 90-day limit per request
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

            console.log(`Received ${Object.keys(data.rates).length} days of data`)

            // Process each date
            for (const [date, eurRates] of Object.entries(data.rates)) {
                const rates = eurRates as Record<string, number>
                const allRates: Record<string, number> = { EUR: 1.0, ...rates }

                // Calculate cross rates for each asset
                for (const asset of assets) {
                    const symbol = asset.symbol.replace(/[\/-]/g, '').toUpperCase()

                    if (symbol.length !== 6) continue

                    const base = symbol.substring(0, 3)
                    const quote = symbol.substring(3, 6)

                    const baseRate = allRates[base]
                    const quoteRate = allRates[quote]

                    if (baseRate && quoteRate) {
                        // For XXXUSD format: 1 XXX = quoteRate / baseRate
                        const crossRate = quoteRate / baseRate

                        // Use Map key to deduplicate
                        const key = `${asset.id}_${date}`
                        priceMap.set(key, {
                            asset_id: asset.id,
                            date: date,
                            open: crossRate,
                            high: crossRate,
                            low: crossRate,
                            close: crossRate,
                            volume: null,
                            provider: 'fx',
                        })
                    }
                }
            }

            // Move to next chunk
            currentStart = new Date(currentEnd)
            currentStart.setDate(currentStart.getDate() + 1)
        }

        // Convert Map to array (deduplicated)
        const historicalPrices = Array.from(priceMap.values())

        console.log(`Generated ${historicalPrices.length} unique historical price records`)

        // Insert in batches
        const batchSize = 1000
        let inserted = 0

        for (let i = 0; i < historicalPrices.length; i += batchSize) {
            const batch = historicalPrices.slice(i, i + batchSize)

            const { error: insertError } = await supabase
                .from('prices_history')
                .upsert(batch, { onConflict: 'asset_id,date' })

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
