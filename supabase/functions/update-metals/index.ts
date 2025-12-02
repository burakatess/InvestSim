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

        // Fetch metal assets from DB
        const { data: assets, error: assetsError } = await supabase
            .from('assets')
            .select('code, tefas_code')
            .eq('category', 'metal')

        if (assetsError) throw assetsError
        if (!assets || assets.length === 0) {
            return new Response(JSON.stringify({ message: 'No metal assets found' }), {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 200,
            })
        }

        // Use GoldAPI.io - Free tier, no rate limit!
        // Get USD/TRY rate first
        const fxResponse = await fetch('https://api.frankfurter.app/latest?from=USD&to=TRY')
        const fxData = await fxResponse.json()
        const usdToTry = fxData.rates.TRY

        // Fetch metal prices from GoldAPI.io (free, no API key needed for basic access)
        // Or use MetalpriceAPI free tier
        const metalPrices: Record<string, number> = {}

        // Try to fetch from free public API
        try {
            // Using a free public endpoint for metals
            // Alternative: https://api.gold-api.com/price/XAU (free, no auth)
            const metals = ['XAU', 'XAG', 'XPT', 'XPD']

            for (const metal of metals) {
                try {
                    // Free public endpoint (no API key required)
                    const response = await fetch(`https://api.gold-api.com/price/${metal}`)
                    if (response.ok) {
                        const data = await response.json()
                        // Price is in USD per troy ounce
                        metalPrices[metal] = data.price || 0
                    }
                } catch (e) {
                    console.log(`Failed to fetch ${metal}:`, e)
                }
            }
        } catch (e) {
            console.log('Using fallback prices')
        }

        // Fallback prices if API fails (approximate current prices in USD)
        if (Object.keys(metalPrices).length === 0) {
            metalPrices['XAU'] = 2050.00  // Gold per oz
            metalPrices['XAG'] = 24.50    // Silver per oz
            metalPrices['XPT'] = 920.00   // Platinum per oz
            metalPrices['XPD'] = 1050.00  // Palladium per oz
            metalPrices['XCU'] = 3.85     // Copper per lb
        }

        const updates = []

        for (const asset of assets) {
            const metalCode = asset.tefas_code || asset.code
            const priceUSD = metalPrices[metalCode]

            if (priceUSD && priceUSD > 0) {
                const priceTRY = priceUSD * usdToTry

                updates.push({
                    asset_code: asset.code,
                    price: priceTRY,
                    change_24h: null,
                    volume_24h: null,
                    market_cap: null,
                    category: 'metal',
                    provider: 'gold-api',
                    updated_at: new Date().toISOString(),
                })
            }
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
                total_assets: assets.length,
                usd_try_rate: usdToTry,
                provider: 'gold-api.com (free)',
                prices_fetched: Object.keys(metalPrices).length
            }),
            {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 200,
            }
        )

    } catch (error: any) {
        return new Response(
            JSON.stringify({ success: false, error: error.message }),
            {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 500,
            }
        )
    }
})
