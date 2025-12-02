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
        // 1. Initialize Supabase Client
        const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
        const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        const supabase = createClient(supabaseUrl, supabaseKey)

        // 2. Fetch Crypto Assets from DB
        const { data: assets, error: assetsError } = await supabase
            .from('assets')
            .select('code')
            .eq('category', 'crypto')

        if (assetsError) throw assetsError
        if (!assets || assets.length === 0) {
            return new Response(JSON.stringify({ message: 'No crypto assets found' }), {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 200,
            })
        }

        // 3. Fetch Market Data from CoinGecko
        const coingeckoResponse = await fetch(
            'https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&order=market_cap_desc&per_page=100&page=1&sparkline=false'
        )

        if (!coingeckoResponse.ok) {
            throw new Error(`CoinGecko API Error: ${coingeckoResponse.statusText}`)
        }

        const marketData = await coingeckoResponse.json()
        const updates = []

        // 4. Match and Prepare Updates
        for (const asset of assets) {
            // Match by symbol (e.g. BTC == btc)
            const marketInfo = marketData.find((m: any) => m.symbol.toUpperCase() === asset.code.toUpperCase())

            if (marketInfo) {
                updates.push({
                    asset_code: asset.code,
                    price: marketInfo.current_price,
                    change_24h: marketInfo.price_change_percentage_24h,
                    volume_24h: marketInfo.total_volume,
                    market_cap: marketInfo.market_cap,
                    category: 'crypto',
                    provider: 'coingecko',
                    updated_at: new Date().toISOString(),
                })
            }
        }

        // 5. Upsert Prices
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
