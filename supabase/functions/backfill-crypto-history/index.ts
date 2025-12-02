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

        // Get parameters
        const { days = 365, batch_size = 50 } = await req.json().catch(() => ({}))

        // Fetch crypto assets
        const { data: assets, error: assetsError } = await supabase
            .from('assets')
            .select('code, coingecko_id')
            .eq('category', 'crypto')
            .not('coingecko_id', 'is', null)
            .limit(batch_size)

        if (assetsError) throw assetsError
        if (!assets || assets.length === 0) {
            return new Response(JSON.stringify({ message: 'No crypto assets found' }), {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 200,
            })
        }

        const historicalPrices: HistoricalPrice[] = []
        let processed = 0
        let failed = 0

        // Process each crypto (with rate limiting)
        for (const asset of assets) {
            try {
                // CoinGecko free tier: market_chart endpoint
                // days: 1-365 for free tier
                const url = `https://api.coingecko.com/api/v3/coins/${asset.coingecko_id}/market_chart?vs_currency=usd&days=${days}&interval=daily`

                const response = await fetch(url)

                if (!response.ok) {
                    console.error(`Failed to fetch ${asset.code}: ${response.statusText}`)
                    failed++
                    continue
                }

                const data = await response.json()

                // Process prices (timestamp, price)
                if (data.prices && Array.isArray(data.prices)) {
                    for (const [timestamp, price] of data.prices) {
                        const date = new Date(timestamp)

                        historicalPrices.push({
                            asset_code: asset.code,
                            date: date.toISOString().split('T')[0],
                            open: price,
                            high: price,
                            low: price,
                            close: price,
                            volume: null,
                            category: 'crypto',
                            provider: 'coingecko',
                        })
                    }
                }

                processed++
                console.log(`Processed ${processed}/${assets.length}: ${asset.code}`)

                // Rate limiting: 50 calls/minute for free tier
                // Wait 1.2 seconds between calls
                await new Promise(resolve => setTimeout(resolve, 1200))

            } catch (error) {
                console.error(`Error processing ${asset.code}:`, error)
                failed++
            }
        }

        // Insert in batches
        const insertBatchSize = 1000
        let inserted = 0

        for (let i = 0; i < historicalPrices.length; i += insertBatchSize) {
            const batch = historicalPrices.slice(i, i + insertBatchSize)

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
                processed: processed,
                failed: failed,
                total_assets: assets.length,
                days: days,
                total_records: historicalPrices.length,
                inserted: inserted,
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
