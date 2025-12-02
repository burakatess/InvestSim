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

        // Fetch top 750 cryptocurrencies from CoinGecko
        const perPage = 250 // CoinGecko max per page
        const pages = 3 // 250 * 3 = 750
        const allCoins = []

        for (let page = 1; page <= pages; page++) {
            const response = await fetch(
                `https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&order=market_cap_desc&per_page=${perPage}&page=${page}&sparkline=false`
            )

            if (!response.ok) {
                throw new Error(`CoinGecko API Error: ${response.statusText}`)
            }

            const coins = await response.json()
            allCoins.push(...coins)

            // Small delay to respect rate limits
            await new Promise(resolve => setTimeout(resolve, 1000))
        }

        // Prepare assets for insertion
        const assets = allCoins.map((coin, index) => ({
            code: `${coin.symbol.toUpperCase()}-${coin.id}`, // Make code unique by adding id
            display_name: coin.name,
            category: 'crypto',
            provider: 'coingecko',
            coingecko_id: coin.id,
            logo_url: coin.image,
            is_active: true,
            market_cap_rank: coin.market_cap_rank,
        }))

        // Insert assets one by one to avoid duplicate issues
        let successCount = 0
        for (const asset of assets) {
            const { error } = await supabase
                .from('assets')
                .upsert(asset, {
                    onConflict: 'code'
                })

            if (!error) successCount++
        }

        return new Response(
            JSON.stringify({
                success: true,
                synced: successCount,
                total: assets.length,
                message: `Synced ${successCount}/${assets.length} crypto assets`
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
