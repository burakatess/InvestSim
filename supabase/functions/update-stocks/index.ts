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

        // Fetch stock assets from DB
        const { data: assets, error: assetsError } = await supabase
            .from('assets')
            .select('code')
            .eq('category', 'stock')

        if (assetsError) throw assetsError
        if (!assets || assets.length === 0) {
            return new Response(JSON.stringify({ message: 'No stock assets found' }), {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 200,
            })
        }

        const updates = []

        // Yahoo Finance API endpoint (using query2.finance.yahoo.com)
        // We'll batch request symbols for efficiency
        const symbols = assets.map(a => a.code).join(',')

        const yahooUrl = `https://query2.finance.yahoo.com/v7/finance/quote?symbols=${symbols}`
        const yahooResponse = await fetch(yahooUrl, {
            headers: {
                'User-Agent': 'Mozilla/5.0',
            }
        })

        if (!yahooResponse.ok) {
            throw new Error(`Yahoo Finance API Error: ${yahooResponse.statusText}`)
        }

        const yahooData = await yahooResponse.json()

        if (!yahooData.quoteResponse || !yahooData.quoteResponse.result) {
            throw new Error('Invalid Yahoo Finance response format')
        }

        // Process each quote
        for (const quote of yahooData.quoteResponse.result) {
            const asset = assets.find(a => a.code === quote.symbol)
            if (!asset) continue

            const price = quote.regularMarketPrice || quote.bid || quote.ask
            if (!price) continue

            updates.push({
                asset_code: asset.code,
                price: price,
                change_24h: quote.regularMarketChangePercent || null,
                volume_24h: quote.regularMarketVolume || null,
                market_cap: quote.marketCap || null,
                category: 'stock',
                provider: 'yahoo',
                updated_at: new Date().toISOString(),
            })
        }

        // Upsert prices
        if (updates.length > 0) {
            const { error: upsertError } = await supabase
                .from('prices')
                .upsert(updates, { onConflict: 'asset_code' })

            if (upsertError) throw upsertError
        }

        return new Response(
            JSON.stringify({
                success: true,
                updated: updates.length,
                total_assets: assets.length
            }),
            {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 200,
            }
        )

    } catch (error) {
        return new Response(
            JSON.stringify({ success: false, error: error.message }),
            {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 500,
            }
        )
    }
})
