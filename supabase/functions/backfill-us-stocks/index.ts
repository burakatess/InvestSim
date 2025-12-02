import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
        const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        const supabase = createClient(supabaseUrl, supabaseKey)

        const { days = 730 } = await req.json().catch(() => ({}))

        // Get US assets
        const { data: assets, error: assetsError } = await supabase
            .from('assets')
            .select('code, symbol, category')
            .in('category', ['us_stock', 'us_etf'])
            .eq('is_active', true)

        if (assetsError) throw assetsError

        console.log(`Found ${assets.length} US assets`)

        // Calculate date range
        const endDate = new Date()
        const startDate = new Date()
        startDate.setDate(startDate.getDate() - days)

        const startTs = Math.floor(startDate.getTime() / 1000)
        const endTs = Math.floor(endDate.getTime() / 1000)

        let totalRecords = 0
        let successCount = 0

        // Fetch historical data for each asset
        for (const asset of assets) {
            try {
                const yahooUrl = `https://query1.finance.yahoo.com/v8/finance/chart/${asset.symbol}?period1=${startTs}&period2=${endTs}&interval=1d&events=history`

                const response = await fetch(yahooUrl, {
                    headers: {
                        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
                    },
                })

                if (!response.ok) {
                    console.error(`Failed to fetch ${asset.symbol}`)
                    continue
                }

                const data = await response.json()
                const result = data.chart?.result?.[0]

                if (!result || !result.timestamp) {
                    console.error(`No data for ${asset.symbol}`)
                    continue
                }

                const timestamps = result.timestamp
                const indicators = result.indicators?.quote?.[0]

                if (!indicators) continue

                const opens = indicators.open || []
                const highs = indicators.high || []
                const lows = indicators.low || []
                const closes = indicators.close || []
                const volumes = indicators.volume || []

                // Build historical prices
                const historicalPrices = []
                for (let i = 0; i < timestamps.length; i++) {
                    if (!closes[i]) continue

                    const date = new Date(timestamps[i] * 1000).toISOString().split('T')[0]

                    historicalPrices.push({
                        asset_code: asset.code,
                        date: date,
                        open: opens[i] || closes[i],
                        high: highs[i] || closes[i],
                        low: lows[i] || closes[i],
                        close: closes[i],
                        volume: volumes[i] || 0,
                        category: asset.category,
                        provider: 'yahoo_finance',
                    })
                }

                // Insert in batches of 500
                const batchSize = 500
                for (let i = 0; i < historicalPrices.length; i += batchSize) {
                    const batch = historicalPrices.slice(i, i + batchSize)

                    const { error: insertError } = await supabase
                        .from('historical_prices')
                        .upsert(batch, { onConflict: 'asset_code,date' })

                    if (insertError) {
                        console.error(`Insert error for ${asset.symbol}:`, insertError)
                        throw insertError
                    }
                }

                totalRecords += historicalPrices.length
                successCount++
                console.log(`✓ ${asset.symbol}: ${historicalPrices.length} records`)

            } catch (error) {
                console.error(`Error processing ${asset.symbol}:`, error)
            }
        }

        return new Response(
            JSON.stringify({
                success: true,
                assets: successCount,
                total: assets.length,
                records: totalRecords,
                message: `Backfilled ${totalRecords} records for ${successCount}/${assets.length} assets`,
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
