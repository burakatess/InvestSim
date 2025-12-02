import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface YahooQuote {
    symbol: string
    regularMarketPrice: number
    regularMarketChange: number
    regularMarketChangePercent: number
    regularMarketTime: number
}

Deno.serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
        const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        const supabase = createClient(supabaseUrl, supabaseKey)

        // Get batch configuration from request or use defaults
        const { batchSize = 5, batchIndex = 0 } = await req.json().catch(() => ({}))

        // Fetch US assets (stocks + ETFs)
        const { data: assets, error: assetsError } = await supabase
            .from('assets')
            .select('code, symbol, category')
            .in('category', ['us_stock', 'us_etf'])
            .eq('is_active', true)

        if (assetsError) throw assetsError
        if (!assets || assets.length === 0) {
            return new Response(JSON.stringify({ message: 'No US assets found' }), {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 200,
            })
        }

        // Calculate batch
        const totalBatches = Math.ceil(assets.length / batchSize)
        const currentBatch = batchIndex % totalBatches
        const startIdx = currentBatch * batchSize
        const endIdx = Math.min(startIdx + batchSize, assets.length)
        const batchAssets = assets.slice(startIdx, endIdx)

        console.log(`Processing batch ${currentBatch + 1}/${totalBatches}: ${batchAssets.length} assets`)

        // Fetch prices from Yahoo Finance (alternative method)
        // Process each symbol individually to avoid rate limiting
        const priceUpdates = []

        for (const asset of batchAssets) {
            try {
                // Use Yahoo Finance v8 API
                const yahooUrl = `https://query1.finance.yahoo.com/v8/finance/chart/${asset.symbol}?interval=1d&range=1d`

                const response = await fetch(yahooUrl, {
                    headers: {
                        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
                    },
                })

                if (!response.ok) {
                    console.error(`Failed to fetch ${asset.symbol}: ${response.status}`)
                    continue
                }

                const data = await response.json()
                const quote = data.chart?.result?.[0]

                if (!quote || !quote.meta) {
                    console.error(`No data for ${asset.symbol}`)
                    continue
                }

                const meta = quote.meta
                const price = meta.regularMarketPrice
                const previousClose = meta.chartPreviousClose || meta.previousClose

                if (!price) {
                    console.error(`No price for ${asset.symbol}`)
                    continue
                }

                const change = price - (previousClose || price)
                const changePercent = previousClose ? ((change / previousClose) * 100) : 0

                priceUpdates.push({
                    asset_code: asset.code,
                    price: price,
                    category: asset.category,
                    provider: 'yahoo_finance',
                })

                console.log(`✓ ${asset.symbol}: $${price.toFixed(2)}`)

            } catch (error) {
                console.error(`Error fetching ${asset.symbol}:`, error)
            }
        }

        // Update prices in database
        let updated = 0
        if (priceUpdates.length > 0) {
            const { error: updateError } = await supabase
                .from('prices')
                .upsert(priceUpdates, { onConflict: 'asset_code' })

            if (updateError) throw updateError
            updated = priceUpdates.length
        }

        return new Response(
            JSON.stringify({
                success: true,
                batch: `${currentBatch + 1}/${totalBatches}`,
                processed: batchAssets.length,
                updated: updated,
                nextBatchIndex: (batchIndex + 1) % totalBatches,
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
