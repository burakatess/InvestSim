import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface PriceHistoryRecord {
    asset_id: string
    date: string
    open: number
    high: number
    low: number
    close: number
    volume: number | null
    provider: string
}

const BINANCE_KLINES_URL = 'https://api.binance.com/api/v3/klines'

Deno.serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
        const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        const supabase = createClient(supabaseUrl, supabaseKey)

        // Get parameters - can specify start_date for historical data
        const { days = 365, batch_size = 50, start_date = null } = await req.json().catch(() => ({}))

        // Calculate date range
        let endTime: number
        let startTime: number

        if (start_date) {
            // If start_date provided, use it as the end point and go back 'days' from there
            endTime = new Date(start_date).getTime()
            startTime = endTime - (days * 24 * 60 * 60 * 1000)
        } else {
            // Default: from now going back
            endTime = Date.now()
            startTime = endTime - (days * 24 * 60 * 60 * 1000)
        }

        // Fetch crypto assets
        const { data: assets, error: assetsError } = await supabase
            .from('assets')
            .select('id, symbol, provider_symbol')
            .eq('asset_class', 'crypto')
            .not('provider_symbol', 'is', null)
            .limit(batch_size)

        if (assetsError) throw assetsError
        if (!assets || assets.length === 0) {
            return new Response(JSON.stringify({ message: 'No crypto assets found' }), {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 200,
            })
        }

        const priceRecords: PriceHistoryRecord[] = []
        let processed = 0
        let failed = 0

        // Process each crypto using Binance API with date range
        for (const asset of assets) {
            try {
                const symbol = asset.provider_symbol || asset.symbol

                // Binance klines with startTime and endTime for specific date range
                // Max 1000 candles per request
                const url = `${BINANCE_KLINES_URL}?symbol=${symbol}&interval=1d&startTime=${startTime}&endTime=${endTime}&limit=1000`

                const response = await fetch(url)

                if (!response.ok) {
                    console.error(`Failed to fetch ${symbol}: ${response.statusText}`)
                    failed++
                    continue
                }

                const data = await response.json()

                // Binance klines format: [openTime, open, high, low, close, volume, closeTime, ...]
                if (Array.isArray(data)) {
                    for (const kline of data) {
                        const [openTime, open, high, low, close, volume] = kline
                        const date = new Date(openTime)

                        priceRecords.push({
                            asset_id: asset.id,
                            date: date.toISOString().split('T')[0],
                            open: parseFloat(open),
                            high: parseFloat(high),
                            low: parseFloat(low),
                            close: parseFloat(close),
                            volume: parseFloat(volume),
                            provider: 'binance',
                        })
                    }
                }

                processed++
                console.log(`Processed ${processed}/${assets.length}: ${symbol} - ${data.length || 0} records`)

                // Binance rate limiting
                await new Promise(resolve => setTimeout(resolve, 100))

            } catch (error) {
                console.error(`Error processing ${asset.symbol}:`, error)
                failed++
            }
        }

        // Insert in batches to price_history table
        const insertBatchSize = 1000
        let inserted = 0

        for (let i = 0; i < priceRecords.length; i += insertBatchSize) {
            const batch = priceRecords.slice(i, i + insertBatchSize)

            const { error: insertError } = await supabase
                .from('price_history')
                .upsert(batch, { onConflict: 'asset_id,date' })

            if (insertError) {
                console.error('Insert error:', insertError)
                throw insertError
            }

            inserted += batch.length
            console.log(`Inserted ${inserted}/${priceRecords.length}`)
        }

        return new Response(
            JSON.stringify({
                success: true,
                processed: processed,
                failed: failed,
                total_assets: assets.length,
                date_range: {
                    start: new Date(startTime).toISOString().split('T')[0],
                    end: new Date(endTime).toISOString().split('T')[0],
                },
                total_records: priceRecords.length,
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
